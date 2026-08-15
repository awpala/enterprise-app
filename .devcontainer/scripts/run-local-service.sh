#!/usr/bin/env bash
# Runs one local application process with persistent lifecycle and application logs.
set -uo pipefail

usage() {
  echo "Usage: $0 <api|ui|data-engine>" >&2
}

if [[ $# -ne 1 ]]; then
  usage
  exit 2
fi

SERVICE_NAME=$1
WORKSPACE_DIR="/workspace"
LOG_DIR="${WORKSPACE_DIR}/__logs/local"

case "$SERVICE_NAME" in
  api)
    SERVICE_DIR="${WORKSPACE_DIR}/api/src/EA.Api"
    SERVICE_COMMAND=(dotnet run)
    ;;
  ui)
    SERVICE_DIR="${WORKSPACE_DIR}/ui"
    SERVICE_COMMAND=(npm run dev)
    ;;
  data-engine)
    SERVICE_DIR="${WORKSPACE_DIR}/data-engine"
    SERVICE_COMMAND=(.venv/bin/python -m data_engine.main)
    ;;
  *)
    echo "Unsupported local service: $SERVICE_NAME" >&2
    usage
    exit 2
    ;;
esac

mkdir -p "$LOG_DIR"

STARTED_AT=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
LOG_TIMESTAMP=$(date -u +'%Y%m%dT%H%M%SZ')
LOG_FILE="${LOG_DIR}/${SERVICE_NAME}-${LOG_TIMESTAMP}.log"
LATEST_LOG="${LOG_DIR}/${SERVICE_NAME}-latest.log"
GIT_REVISION=$(git -C "$WORKSPACE_DIR" rev-parse --short=12 HEAD 2>/dev/null || echo unknown)

ln -sfn "$(basename "$LOG_FILE")" "$LATEST_LOG"

log_lifecycle() {
  printf '%s service=%s event=%s pid=%s git=%s' \
    "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
    "$SERVICE_NAME" \
    "$1" \
    "$$" \
    "$GIT_REVISION"
  shift
  if [[ $# -gt 0 ]]; then
    printf ' %s' "$*"
  fi
  printf '\n'
}

on_signal() {
  local signal_name=$1
  log_lifecycle signal "name=${signal_name}"
}

trap 'on_signal INT' INT
trap 'on_signal TERM' TERM

cd "$SERVICE_DIR"

{
  log_lifecycle start "started_at=${STARTED_AT} cwd=${SERVICE_DIR} command=${SERVICE_COMMAND[*]} log=${LOG_FILE}"
  "${SERVICE_COMMAND[@]}"
  SERVICE_EXIT_CODE=$?
  log_lifecycle exit "exit_code=${SERVICE_EXIT_CODE}"
  exit "$SERVICE_EXIT_CODE"
} 2>&1 | tee -a "$LOG_FILE"

exit "${PIPESTATUS[0]}"
