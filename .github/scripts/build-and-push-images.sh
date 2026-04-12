#!/usr/bin/env bash
# Builds and pushes ea-api, ea-migrations, ea-data-engine images via az acr build.
# Expects IMAGE_TAG in env and terraform state available under infra/.
set -euo pipefail

cd "${GITHUB_WORKSPACE}"

ACR_NAME=$(terraform -chdir="${GITHUB_WORKSPACE}/infra" output -raw acr_name)
echo "::add-mask::$ACR_NAME"
az acr login --name "$ACR_NAME"

az acr build \
  --registry "$ACR_NAME" \
  --image "ea-api:${IMAGE_TAG}" \
  --file api/Dockerfile \
  api/

az acr build \
  --registry "$ACR_NAME" \
  --image "ea-migrations:${IMAGE_TAG}" \
  --file api/Dockerfile.migrations \
  api/

az acr build \
  --registry "$ACR_NAME" \
  --image "ea-data-engine:${IMAGE_TAG}" \
  --file data-engine/Dockerfile \
  data-engine/
