#!/usr/bin/env bash
# Resolves cloud targets and changed services for deploy.yml. Push policy is
# explicit; manual dispatch selects a provider without changing that policy.
# Writes GitHub Actions outputs and performs no remote operations.
set -euo pipefail

: "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required.}"

case "${GITHUB_EVENT_NAME:-}" in
  workflow_dispatch)
    selected=${MANUAL_TARGET:-}
    environment=${MANUAL_ENVIRONMENT:-}
    case "$environment" in
      dev|production) ;;
      *) echo "Manual environment must be dev or production." >&2; exit 2 ;;
    esac
    case "${selected,,}" in
      azure|aws|both|azure,aws|aws,azure) ;;
      *) echo "Manual target must explicitly select azure, aws, or both." >&2; exit 2 ;;
    esac
    ;;
  push)
    selected=${CONFIGURED_TARGETS:-}
    if [[ -z "$selected" ]]; then
      echo "DEPLOYMENT_TARGETS must explicitly be none, azure, aws, or both for push deployments." >&2
      exit 2
    fi
    if [[ "${GITHUB_REF:-}" == "refs/heads/main" ]]; then
      environment=production
    else
      environment=dev
    fi
    ;;
  *) echo "Unsupported deployment event: ${GITHUB_EVENT_NAME:-unset}" >&2; exit 2 ;;
esac

azure_enabled=false
aws_enabled=false
case "${selected,,}" in
  none) ;;
  azure) azure_enabled=true ;;
  aws) aws_enabled=true ;;
  both|azure,aws|aws,azure) azure_enabled=true; aws_enabled=true ;;
  *) echo "Unsupported deployment target selection: $selected" >&2; exit 2 ;;
esac

api_changed=false
data_engine_changed=false
ui_changed=false
if [[ "$azure_enabled" == true || "$aws_enabled" == true ]]; then
  api_changed=true
  data_engine_changed=true
  ui_changed=true
  if [[ "$GITHUB_EVENT_NAME" == push ]]; then
    : "${GITHUB_SHA:?GITHUB_SHA is required for cloud push deployments.}"
    base=${PUSH_BEFORE:-}
    if [[ -z "$base" || "$base" =~ ^0+$ ]] || ! git cat-file -e "${base}^{commit}" 2>/dev/null; then
      if [[ "${GITHUB_REF:-}" == "refs/heads/main" ]]; then
        base="${GITHUB_SHA}~1"
      else
        base=$(git merge-base origin/main HEAD)
      fi
    fi
    changed=$(git diff --name-only "$base" "$GITHUB_SHA" --)
    api_changed=$(grep -q '^api/' <<<"$changed" && echo true || echo false)
    data_engine_changed=$(grep -q '^data-engine/' <<<"$changed" && echo true || echo false)
    ui_changed=$(grep -q '^ui/' <<<"$changed" && echo true || echo false)
  fi
else
  echo "Cloud push deployment is disabled (DEPLOYMENT_TARGETS=none)."
fi

{
  echo "environment=$environment"
  echo "azure_enabled=$azure_enabled"
  echo "aws_enabled=$aws_enabled"
  echo "api_changed=$api_changed"
  echo "data_engine_changed=$data_engine_changed"
  echo "ui_changed=$ui_changed"
} >> "$GITHUB_OUTPUT"
