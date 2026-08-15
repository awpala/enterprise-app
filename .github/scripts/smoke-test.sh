#!/usr/bin/env bash
# Smoke tests the deployed API and browser runtime configuration with retries.
# Expects Terraform state available under the selected provider root.
set -euo pipefail

: "${TF_ROOT:?TF_ROOT must explicitly select a provider root, for example infra/azure or infra/aws.}"
API_URL=$(terraform -chdir="$TF_ROOT" output -raw api_url)
APPLICATION_URL=$(terraform -chdir="$TF_ROOT" output -raw application_url)
echo "::add-mask::$API_URL"
echo "::add-mask::$APPLICATION_URL"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

check_managed_login() {
  local runtime_config authority client_id api_scope authorization_endpoint status
  runtime_config=$(curl -fsS "$APPLICATION_URL/api/runtime-config")
  authority=$(jq -r '.auth.authority' <<<"$runtime_config")
  client_id=$(jq -r '.auth.clientId' <<<"$runtime_config")
  api_scope=$(jq -r '.auth.apiScope' <<<"$runtime_config")
  authorization_endpoint=$(curl -fsS \
    "$authority/.well-known/openid-configuration" | jq -r '.authorization_endpoint')

  status=$(curl -sS -L -o "$TEMP_DIR/managed-login.html" -w '%{http_code}' \
    --cookie-jar "$TEMP_DIR/cookies" --cookie "$TEMP_DIR/cookies" \
    --get "$authorization_endpoint" \
    --data-urlencode "client_id=$client_id" \
    --data-urlencode 'response_type=code' \
    --data-urlencode "redirect_uri=$APPLICATION_URL/auth/callback" \
    --data-urlencode "scope=openid profile email $api_scope" \
    --data-urlencode 'state=deployment-smoke-test' \
    --data-urlencode 'code_challenge=ZHVtbXktcGtjZS1jaGFsbGVuZ2UtdmFsdWU' \
    --data-urlencode 'code_challenge_method=S256')

  [[ "$status" == "200" ]]
}

for i in 1 2 3 4 5 6; do
  if curl -fsS "$API_URL/health/ready" \
    && curl -fsS "$APPLICATION_URL/api/health" \
    && curl -fsS "$APPLICATION_URL/api/runtime-config" \
    && check_managed_login; then
    echo
    echo "API, browser runtime configuration, and managed login ready."
    exit 0
  fi
  echo "Attempt $i failed, sleeping 10s..."
  sleep 10
done
echo "API, browser runtime configuration, or managed login never returned 200" >&2
exit 1
