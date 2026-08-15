#!/usr/bin/env bash
set -euo pipefail

# predefined and derived constants
BASH_RC="/root/.bashrc"
WORKSPACE_DIR="/workspace"
LOGFILE="/tmp/setup-env-debug.log"

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

# ensure /root/.bashrc file exists
touch "$BASH_RC"

# post-process /root/.bashrc
if [ -f "$BASH_RC" ]; then
  echo "Patching $BASH_RC (uncommenting colorized LS aliases)"
  sed -i -E 's/^#\s*export\s+/export /' "$BASH_RC" || true
  sed -i -E 's/^#\s*eval\s+/eval /' "$BASH_RC" || true
  sed -i -E 's/^#\s*alias\s+l/alias l/' "$BASH_RC" || true
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
