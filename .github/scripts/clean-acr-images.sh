#!/usr/bin/env bash
# clean-acr-images.sh
#
# Removes stale tags from all repositories in an Azure Container Registry.
#
# Behavior:
# - Reads the ACR name from Terraform output (no hardcoded values).
# - Lists every repository in the ACR.
# - Keeps only the most recent tag per repository (by timestamp).
# - Also keeps the `latest` tag when present.
# - Deletes every other tag in that repository.
#
# Prerequisites:
# - Azure CLI authenticated (OIDC login in CI).
# - Terraform initialized with the correct backend state.
# - `jq` installed (available on GitHub-hosted runners).
#
# Usage (CI): called by .github/workflows/cleanup-acr.yml
# Usage (local): ensure `az login` and `terraform init` have been run first.

set -euo pipefail

# ---------------------------------------------------------------------------
# Resolve ACR name from Terraform state
# ---------------------------------------------------------------------------
ACR_NAME=$(terraform -chdir="${GITHUB_WORKSPACE:-/workspace}/infra" output -raw acr_name)
echo "ACR name resolved from Terraform output: ${ACR_NAME}"

# ---------------------------------------------------------------------------
# Authenticate to ACR
# ---------------------------------------------------------------------------
echo "Logging into ACR: ${ACR_NAME}"
az acr login --name "$ACR_NAME"

# ---------------------------------------------------------------------------
# Iterate repositories and prune stale tags
# ---------------------------------------------------------------------------
echo "Fetching repositories from ACR: ${ACR_NAME}"
REPOS=$(az acr repository list --name "$ACR_NAME" -o tsv)

if [ -z "$REPOS" ]; then
  echo "No repositories found in ACR. Nothing to clean."
  exit 0
fi

for REPO in $REPOS; do
  echo ""
  echo "Processing repository: ${REPO}"

  # Get tags with timestamps, most recent first
  TAG_DATA=$(az acr repository show-tags \
    --name "$ACR_NAME" \
    --repository "$REPO" \
    --detail \
    --orderby time_desc \
    -o json)

  TAG_COUNT=$(echo "$TAG_DATA" | jq length)

  if [ "$TAG_COUNT" -eq 0 ]; then
    echo "  No tags found, skipping."
    continue
  fi

  # Most recent tag (first entry due to time_desc ordering)
  MOST_RECENT=$(echo "$TAG_DATA" | jq -r '.[0].name')

  # Check if 'latest' tag exists
  HAS_LATEST=$(echo "$TAG_DATA" | jq -r '[.[] | select(.name=="latest")] | length')

  echo "  Most recent tag: ${MOST_RECENT}"
  if [ "$HAS_LATEST" -gt 0 ]; then
    echo "  Found 'latest' tag."
  fi

  # Build the set of tags to keep
  KEEP_TAGS=("$MOST_RECENT")
  if [ "$HAS_LATEST" -gt 0 ] && [ "$MOST_RECENT" != "latest" ]; then
    KEEP_TAGS+=("latest")
  fi

  echo "  Keeping tags: ${KEEP_TAGS[*]}"

  # Nothing to prune if the only tags are the ones we're keeping.
  if [ "$TAG_COUNT" -le "${#KEEP_TAGS[@]}" ]; then
    echo "  Nothing to prune."
    continue
  fi

  # Walk all tags and delete those not in the keep set.
  # Tolerate "tag does not exist" errors — multiple tags can share a
  # manifest digest, so deleting one tag may remove sibling tags too.
  ALL_TAGS=$(echo "$TAG_DATA" | jq -r '.[].name')

  for TAG in $ALL_TAGS; do
    KEEP=false
    for K in "${KEEP_TAGS[@]}"; do
      if [ "$TAG" == "$K" ]; then
        KEEP=true
        break
      fi
    done

    if [ "$KEEP" = true ]; then
      echo "  Keeping  ${REPO}:${TAG}"
    else
      echo "  Deleting ${REPO}:${TAG}"
      az acr repository delete \
        --name "$ACR_NAME" \
        --image "$REPO:$TAG" \
        --yes 2>/dev/null || echo "  (already removed — shared manifest)"
    fi
  done
done

echo ""
echo "Cleanup complete."
