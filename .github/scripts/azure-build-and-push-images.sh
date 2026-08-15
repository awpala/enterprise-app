#!/usr/bin/env bash
# Azure adapter: builds and pushes container images via az acr build.
# Skips unchanged images and re-tags them to the current IMAGE_TAG.
#
# Expects in env:
#   IMAGE_TAG            — target tag for this deploy (e.g. sha-abc1234)
#   API_CHANGED          — "true" if api/ has changes
#   DATA_ENGINE_CHANGED  — "true" if data-engine/ has changes
#   UI_CHANGED           — "true" if ui/ has changes
#
# Requires Terraform state available under infra/azure and az CLI authenticated.
set -euo pipefail

cd "${GITHUB_WORKSPACE}"

ACR_NAME=$(terraform -chdir="${GITHUB_WORKSPACE}/infra/azure" output -raw acr_name)
echo "::add-mask::$ACR_NAME"
az acr login --name "$ACR_NAME"

ACR_LOGIN_SERVER=$(terraform -chdir="${GITHUB_WORKSPACE}/infra/azure" output -raw acr_login_server)

# re_tag <repository>
# Copies the most recent existing tag to IMAGE_TAG for an unchanged image.
re_tag() {
  local repo="$1"
  local latest_tag
  latest_tag=$(az acr repository show-tags \
    --name "$ACR_NAME" \
    --repository "$repo" \
    --orderby time_desc \
    --top 1 \
    -o tsv 2>/dev/null || echo "")

  if [[ -z "$latest_tag" ]]; then
    echo "WARNING: No existing tag found for $repo — building from scratch"
    return 1
  fi

  echo "Re-tagging $repo:$latest_tag -> $repo:${IMAGE_TAG}"
  az acr import \
    --name "$ACR_NAME" \
    --source "${ACR_LOGIN_SERVER}/${repo}:${latest_tag}" \
    --image "${repo}:${IMAGE_TAG}" \
    --force
}

# --- ea-api ---
if [[ "${API_CHANGED:-true}" == "true" ]]; then
  echo "Building ea-api (api/ changed)"
  az acr build \
    --registry "$ACR_NAME" \
    --image "ea-api:${IMAGE_TAG}" \
    --file api/Dockerfile \
    api/
else
  echo "Skipping ea-api build (no api/ changes)"
  re_tag "ea-api" || az acr build --registry "$ACR_NAME" --image "ea-api:${IMAGE_TAG}" --file api/Dockerfile api/
fi

# --- ea-ui ---
if [[ "${UI_CHANGED:-true}" == "true" ]]; then
  echo "Building ea-ui (ui/ changed)"
  az acr build \
    --registry "$ACR_NAME" \
    --image "ea-ui:${IMAGE_TAG}" \
    --file ui/Dockerfile \
    ui/
else
  echo "Skipping ea-ui build (no ui/ changes)"
  re_tag "ea-ui" || az acr build --registry "$ACR_NAME" --image "ea-ui:${IMAGE_TAG}" --file ui/Dockerfile ui/
fi

# --- ea-migrations ---
if [[ "${API_CHANGED:-true}" == "true" ]]; then
  echo "Building ea-migrations (api/ changed)"
  az acr build \
    --registry "$ACR_NAME" \
    --image "ea-migrations:${IMAGE_TAG}" \
    --file api/Dockerfile.migrations \
    api/
else
  echo "Skipping ea-migrations build (no api/ changes)"
  re_tag "ea-migrations" || az acr build --registry "$ACR_NAME" --image "ea-migrations:${IMAGE_TAG}" --file api/Dockerfile.migrations api/
fi

# --- ea-data-engine ---
if [[ "${DATA_ENGINE_CHANGED:-true}" == "true" ]]; then
  echo "Building ea-data-engine (data-engine/ changed)"
  az acr build \
    --registry "$ACR_NAME" \
    --image "ea-data-engine:${IMAGE_TAG}" \
    --file data-engine/Dockerfile \
    data-engine/
else
  echo "Skipping ea-data-engine build (no data-engine/ changes)"
  re_tag "ea-data-engine" || az acr build --registry "$ACR_NAME" --image "ea-data-engine:${IMAGE_TAG}" --file data-engine/Dockerfile data-engine/
fi
