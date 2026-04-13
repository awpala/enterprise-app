#!/usr/bin/env bash
# Reads build-time config from terraform outputs, masks sensitive values, and
# builds the Angular UI bundle.
#
# Expected terraform outputs (see infra/outputs.tf):
#   - api_url         → API_URL
#   - aad_authority   → AAD_AUTHORITY
#   - aad_client_id   → AAD_CLIENT_ID
#   - aad_tenant_id   → AAD_TENANT_ID
#   - aad_api_scope   → AAD_API_SCOPE
#
# Plus two caller-provided env vars:
#   - ENABLE_DEV_AUTH    — exposes the "Log in as Dev" button on the landing
#                          page. deploy.yml sets this to "true" for dev and
#                          "false" for prod.
#   - ENABLE_GUEST_AUTH  — exposes the "Log in as Guest" prod-only failsafe
#                          on the landing page. deploy.yml sets this to
#                          "true" for prod and "false" everywhere else.
#                          Independent of ENABLE_DEV_AUTH.
#
# Requires terraform state available under infra/ and Node/npm installed.
set -euo pipefail

API_URL=$(terraform -chdir=infra output -raw api_url)
AAD_AUTHORITY=$(terraform -chdir=infra output -raw aad_authority)
AAD_CLIENT_ID=$(terraform -chdir=infra output -raw aad_client_id)
AAD_TENANT_ID=$(terraform -chdir=infra output -raw aad_tenant_id)
AAD_API_SCOPE=$(terraform -chdir=infra output -raw aad_api_scope)

# Mask values in GitHub Actions logs. These are not secrets but avoid leaking
# tenant-identifying URLs into public PR logs.
echo "::add-mask::$API_URL"
echo "::add-mask::$AAD_AUTHORITY"
echo "::add-mask::$AAD_CLIENT_ID"
echo "::add-mask::$AAD_TENANT_ID"
echo "::add-mask::$AAD_API_SCOPE"

cd ui
npm ci
API_URL="$API_URL" \
  AAD_AUTHORITY="$AAD_AUTHORITY" \
  AAD_CLIENT_ID="$AAD_CLIENT_ID" \
  AAD_TENANT_ID="$AAD_TENANT_ID" \
  AAD_API_SCOPE="$AAD_API_SCOPE" \
  ENABLE_DEV_AUTH="${ENABLE_DEV_AUTH:-false}" \
  ENABLE_GUEST_AUTH="${ENABLE_GUEST_AUTH:-false}" \
  npm run build:prod
