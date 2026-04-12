#!/usr/bin/env bash
# Smoke tests the deployed API by polling /health/ready with retries.
# Expects terraform state available under infra/.
set -euo pipefail

API_URL=$(terraform -chdir=infra output -raw api_url)
echo "::add-mask::$API_URL"
for i in 1 2 3 4 5 6; do
  if curl -fsS "$API_URL/health/ready"; then
    echo
    echo "API ready."
    exit 0
  fi
  echo "Attempt $i failed, sleeping 10s..."
  sleep 10
done
echo "API /health/ready never returned 200" >&2
exit 1
