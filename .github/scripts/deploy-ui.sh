#!/usr/bin/env bash
# Deploys the built Angular UI to Azure Static Web Apps using the swa CLI.
# Expects terraform state available under infra/ and swa CLI on PATH.
set -euo pipefail

cd "${GITHUB_WORKSPACE}"

SWA_TOKEN=$(terraform -chdir=infra output -raw swa_deployment_token)
echo "::add-mask::$SWA_TOKEN"
swa deploy ui/dist/ui/browser \
  --deployment-token "$SWA_TOKEN" \
  --env production
