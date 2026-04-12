#!/usr/bin/env bash
# Reads API_URL from terraform output, masks it, and builds the Angular UI.
# Expects terraform state available under infra/ and Node/npm installed.
set -euo pipefail

API_URL=$(terraform -chdir=infra output -raw api_url)
echo "::add-mask::$API_URL"
cd ui
npm ci
API_URL="$API_URL" npm run build:prod
