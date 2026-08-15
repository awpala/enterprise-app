#!/usr/bin/env bash
# Computes ENV_NAME, TFSTATE_KEY, TFVARS_FILE, and IMAGE_TAG from an explicit
# DEPLOY_ENVIRONMENT or, for push workflows, GITHUB_REF/GITHUB_REF_NAME.
# Writes them to both $GITHUB_OUTPUT and $GITHUB_ENV. Requires git in cwd.
set -euo pipefail

SHORT_SHA=$(git rev-parse --short=7 HEAD)
if [[ -n "${DEPLOY_ENVIRONMENT:-}" ]]; then
  case "$DEPLOY_ENVIRONMENT" in
    dev|production) ENV_NAME="$DEPLOY_ENVIRONMENT" ;;
    *) echo "Unsupported DEPLOY_ENVIRONMENT: $DEPLOY_ENVIRONMENT" >&2; exit 2 ;;
  esac
elif [[ "${GITHUB_REF:-}" == "refs/heads/main" ]]; then
  ENV_NAME="production"
else
  ENV_NAME="dev"
fi

if [[ "$ENV_NAME" == "production" ]]; then
  TFSTATE_KEY="production.tfstate"
  TFVARS_FILE="envs/production.tfvars"
  IMAGE_TAG="sha-${SHORT_SHA}"
else
  TFSTATE_KEY="dev.tfstate"
  TFVARS_FILE="envs/dev.tfvars"
  # Branch slug: lowercase, / → -, keep only [a-z0-9-], collapse dashes, trim.
  BRANCH_RAW="${GITHUB_REF_NAME:-manual}"
  BRANCH_SLUG=$(printf '%s' "$BRANCH_RAW" \
    | tr '[:upper:]' '[:lower:]' \
    | tr '/' '-' \
    | sed 's/[^a-z0-9-]//g' \
    | sed 's/-\{2,\}/-/g' \
    | sed 's/^-//; s/-$//')
  if [[ -z "$BRANCH_SLUG" ]]; then
    BRANCH_SLUG="branch"
  fi
  IMAGE_TAG="${BRANCH_SLUG}-${SHORT_SHA}"
fi

{
  echo "env_name=$ENV_NAME"
  echo "tfstate_key=$TFSTATE_KEY"
  echo "tfvars_file=$TFVARS_FILE"
  echo "image_tag=$IMAGE_TAG"
} >> "$GITHUB_OUTPUT"
{
  echo "ENV_NAME=$ENV_NAME"
  echo "TFSTATE_KEY=$TFSTATE_KEY"
  echo "TFVARS_FILE=$TFVARS_FILE"
  echo "IMAGE_TAG=$IMAGE_TAG"
} >> "$GITHUB_ENV"
