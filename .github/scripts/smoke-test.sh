#!/usr/bin/env bash
# Smoke tests the deployed API and browser runtime configuration with retries.
# Expects Terraform state available under the selected provider root.
set -euo pipefail

: "${TF_ROOT:?TF_ROOT must explicitly select a provider root, for example infra/azure or infra/aws.}"
API_URL=$(terraform -chdir="$TF_ROOT" output -raw api_url)
APPLICATION_URL=$(terraform -chdir="$TF_ROOT" output -raw application_url)
echo "::add-mask::$API_URL"
echo "::add-mask::$APPLICATION_URL"
for i in 1 2 3 4 5 6; do
  if curl -fsS "$API_URL/health/ready" \
    && curl -fsS "$APPLICATION_URL/api/health" \
    && curl -fsS "$APPLICATION_URL/api/runtime-config"; then
    echo
    echo "API and browser runtime configuration ready."
    exit 0
  fi
  echo "Attempt $i failed, sleeping 10s..."
  sleep 10
done
echo "API or browser runtime configuration never returned 200" >&2
exit 1
