#!/usr/bin/env bash
set -euo pipefail

# predefined and derived constants
BASH_RC="/root/.bashrc"
BASH_ALIASES="/root/.bash_aliases"
WORKSPACE_DIR="/workspace"
LOGFILE="/tmp/setup-env-debug.log"
GOOGLE_CLOUD_APT_KEY_URL="https://packages.cloud.google.com/apt/doc/apt-key.gpg"
GOOGLE_CLOUD_APT_KEYRING="/usr/share/keyrings/cloud.google.gpg"
GOOGLE_CLOUD_APT_SOURCE_FILE="/etc/apt/sources.list.d/google-cloud-sdk.list"
GOOGLE_CLOUD_APT_SOURCE="deb [signed-by=${GOOGLE_CLOUD_APT_KEYRING}] https://packages.cloud.google.com/apt cloud-sdk main"

# redirect all output to logfile (and still echo to stdout for visibility)
exec > >(tee -a "$LOGFILE") 2>&1

echo "===== setup-env.sh DEBUG LOG START ====="
date
echo "Working directory: $PWD"
uname -a
echo

echo "--- Environment (sorted) ---"
printenv | sort
echo

# ensure /root/.bashrc and /root/.bash_aliases files exist
touch "$BASH_RC"
touch "$BASH_ALIASES"

# post-process /root/.bashrc
if [ -f "$BASH_RC" ]; then
  echo "Patching $BASH_RC (uncommenting colorized LS aliases)"
  sed -i -E 's/^#\s*export\s+/export /' "$BASH_RC" || true
  sed -i -E 's/^#\s*eval\s+/eval /' "$BASH_RC" || true
  sed -i -E 's/^#\s*alias\s+l/alias l/' "$BASH_RC" || true

  if ! grep -q 'bash_aliases' "$BASH_RC" 2>/dev/null; then
    cat >> "$BASH_RC" <<'EOF'
if [ -f ~/.bash_aliases ]; then
  . ~/.bash_aliases
fi
EOF
  fi
fi

# write dedicated /root/.bash_aliases entries
if ! grep -q '^export ui=' "$BASH_ALIASES" 2>/dev/null; then
  echo 'export ui="/workspace/ui"' >> "$BASH_ALIASES"
fi
if ! grep -q '^export api=' "$BASH_ALIASES" 2>/dev/null; then
  echo 'export api="/workspace/api/src/EA.Api"' >> "$BASH_ALIASES"
fi
if ! grep -q '^export data_engine=' "$BASH_ALIASES" 2>/dev/null; then
  echo 'export data_engine="/workspace/data-engine"' >> "$BASH_ALIASES"
fi
if ! grep -q '^alias run-ui=' "$BASH_ALIASES" 2>/dev/null; then
  echo "alias run-ui='cd \"\$ui\" && npm run dev'" >> "$BASH_ALIASES"
fi
if ! grep -q '^alias run-api=' "$BASH_ALIASES" 2>/dev/null; then
  echo "alias run-api='cd \"\$api\" && dotnet run'" >> "$BASH_ALIASES"
fi
if ! grep -q '^alias run-data-engine=' "$BASH_ALIASES" 2>/dev/null; then
  echo "alias run-data-engine='cd \"\$data_engine\" && .venv/bin/python -m data_engine.main'" >> "$BASH_ALIASES"
fi

on_error() {
  rc=$?
  echo "ERROR: setup-env.sh failed with exit code $rc at line ${BASH_LINENO[0]}"
  echo "Tail of logfile $LOGFILE as follows:";
  tail -n 200 "$LOGFILE" || true
}
trap on_error ERR

# ---- Search tooling ----
if command -v rg >/dev/null 2>&1; then
  echo "ripgrep is already installed: $(rg --version | head -n 1)"
elif command -v apt-get >/dev/null 2>&1; then
  echo "--- Installing ripgrep ---"
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends ripgrep
  echo "Installed: $(rg --version | head -n 1)"
else
  echo "ERROR: ripgrep is missing and apt-get is unavailable." >&2
  exit 1
fi

# ---- Google Cloud CLI ----
if command -v gcloud >/dev/null 2>&1; then
  echo "Google Cloud CLI is already installed: $(gcloud version 2>/dev/null | sed -n '1p')"
elif command -v apt-get >/dev/null 2>&1; then
  echo "--- Installing Google Cloud CLI ---"
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends \
    ca-certificates \
    curl \
    gnupg
  curl --fail --silent --show-error --location "$GOOGLE_CLOUD_APT_KEY_URL" \
    | gpg --dearmor --yes --output "$GOOGLE_CLOUD_APT_KEYRING"
  printf '%s\n' "$GOOGLE_CLOUD_APT_SOURCE" > "$GOOGLE_CLOUD_APT_SOURCE_FILE"
  apt-get update
  CLOUDSDK_SKIP_PY_COMPILATION=1 DEBIAN_FRONTEND=noninteractive \
    apt-get install --yes --no-install-recommends google-cloud-cli
  command -v gcloud >/dev/null 2>&1 || {
    echo "ERROR: Google Cloud CLI installation completed without a gcloud executable." >&2
    exit 1
  }
  echo "Installed Google Cloud CLI: $(gcloud version | sed -n '1p')"
else
  echo "ERROR: Google Cloud CLI is missing and apt-get is unavailable." >&2
  exit 1
fi

# ---- Next.js frontend: install npm dependencies ----
UI_DIR="${WORKSPACE_DIR}/ui"
if [ -f "${UI_DIR}/package.json" ]; then
  echo "--- Installing Next.js frontend dependencies ---"
  cd "${UI_DIR}"
  npm ci --prefer-offline 2>&1 || npm install 2>&1 || echo "npm install failed (will retry manually)"
  echo "Next.js version: $(npm exec -- next --version 2>/dev/null || echo 'not available')"
  echo "Next.js frontend dependencies installed."
  cd "${WORKSPACE_DIR}"
else
  echo "No Next.js frontend found at ${UI_DIR}/package.json — skipping npm install."
fi

# ---- Data Engine: create Python virtual environment and install dependencies ----
DATA_ENGINE_DIR="${WORKSPACE_DIR}/data-engine"
DATA_ENGINE_VENV="${DATA_ENGINE_DIR}/.venv"
if [ -f "${DATA_ENGINE_DIR}/pyproject.toml" ]; then
  echo "--- Setting up Python virtual environment for data-engine ---"

  # Create the venv only if it does not already exist (idempotent)
  if [ -d "${DATA_ENGINE_VENV}" ]; then
    echo "Virtual environment already exists at ${DATA_ENGINE_VENV} — skipping creation."
  else
    echo "Creating virtual environment at ${DATA_ENGINE_VENV}..."
    python3 -m venv "${DATA_ENGINE_VENV}" 2>&1 || echo "venv creation failed (will retry manually)"
  fi

  # Upgrade pip and install the package in editable mode with dev dependencies
  if [ -x "${DATA_ENGINE_VENV}/bin/pip" ]; then
    echo "Upgrading pip inside the virtual environment..."
    "${DATA_ENGINE_VENV}/bin/pip" install --upgrade pip 2>&1 || echo "pip upgrade failed (non-fatal)"

    echo "Installing data-engine package in editable mode with dev dependencies..."
    cd "${DATA_ENGINE_DIR}"
    "${DATA_ENGINE_VENV}/bin/pip" install -e ".[dev]" 2>&1 || echo "data-engine pip install failed (will retry manually)"
    cd "${WORKSPACE_DIR}"
    echo "Data-engine dependencies installed."
  else
    echo "pip not found in ${DATA_ENGINE_VENV} — virtual environment may be broken."
  fi

  # Add the venv bin directory to PATH in .bashrc (idempotent)
  VENV_PATH_ENTRY="export PATH=\"${DATA_ENGINE_VENV}/bin:\$PATH\""
  if ! grep -qF "${DATA_ENGINE_VENV}/bin" "$BASH_RC" 2>/dev/null; then
    echo "${VENV_PATH_ENTRY}" >> "$BASH_RC"
    echo "Added data-engine venv to PATH in $BASH_RC"
  else
    echo "Data-engine venv PATH entry already present in $BASH_RC — skipping."
  fi
else
  echo "No data-engine project found at ${DATA_ENGINE_DIR}/pyproject.toml — skipping Python venv setup."
fi

echo "===== setup-env.sh DEBUG LOG END ====="
echo

echo "Setup script finished (see $LOGFILE for details). Open a new terminal in VS Code to run ad hoc commands."
