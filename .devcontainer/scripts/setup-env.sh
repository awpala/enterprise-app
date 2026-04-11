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

# ---- Angular CLI: install globally ----
echo "--- Installing Angular CLI globally ---"
npm install -g @angular/cli 2>&1 || echo "Angular CLI global install failed (will retry manually)"
echo "Angular CLI version: $(ng --version 2>/dev/null | head -1 || echo 'not available')"

# ---- TypeScript CLI: install globally ----
echo "--- Installing TypeScript globally ---"
if command -v tsc >/dev/null 2>&1; then
  echo "TypeScript already available: $(tsc --version 2>/dev/null || echo 'version unknown')"
else
  npm install -g typescript@latest 2>&1 || echo "TypeScript global install failed (will retry manually)"
  echo "TypeScript version: $(tsc --version 2>/dev/null || echo 'not available')"
fi

# ---- Claude CLI: install globally via native install ----
echo "--- Installing Claude CLI globally ---"
if command -v claude >/dev/null 2>&1; then
  echo "claude CLI already available: $(claude --version 2>/dev/null || echo 'version unknown')"
else
  echo "Attempting native Claude installer (non-fatal on failure)..."
  # run installer but don't let a non-zero exit stop the whole script
  set +e
  curl -fsSL https://claude.ai/install.sh | bash -s -- || true
  INSTALL_RC=$?
  set -e

  # If installer placed binary in ~/.local/bin, add it to PATH for this run
  if [ -x "$HOME/.local/bin/claude" ]; then
    export PATH="$HOME/.local/bin:$PATH"
    if [ -f "$BASH_RC" ] && ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$BASH_RC" 2>/dev/null; then
      echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$BASH_RC"
      echo "Added ~/.local/bin to $BASH_RC"
    fi
  fi

  # Resolve the binary and report version without causing script failure
  CLAUDE_BIN=$(command -v claude || echo "$HOME/.local/bin/claude")
  if [ -x "$CLAUDE_BIN" ]; then
    CLAUDE_VER=$("$CLAUDE_BIN" --version 2>/dev/null || true)
    echo "claude CLI version: ${CLAUDE_VER:-available but version not reported}"
  else
    echo "claude CLI version: not available"
    echo "If the installer reported '~/.local/bin' is not in PATH, run:" 
    echo "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> $BASH_RC && source $BASH_RC"
  fi
fi

# ---- Angular frontend: install npm dependencies ----
UI_DIR="${WORKSPACE_DIR}/ui"
if [ -f "${UI_DIR}/package.json" ]; then
  echo "--- Installing Angular frontend dependencies ---"
  cd "${UI_DIR}"
  npm ci --prefer-offline 2>&1 || npm install 2>&1 || echo "npm install failed (will retry manually)"
  echo "Angular frontend dependencies installed."
  cd "${WORKSPACE_DIR}"
else
  echo "No Angular frontend found at ${UI_DIR}/package.json — skipping npm install."
fi

echo "===== setup-env.sh DEBUG LOG END ====="
echo

echo "Setup script finished (see $LOGFILE for details). Open a new terminal in VS Code to run ad hoc commands."
