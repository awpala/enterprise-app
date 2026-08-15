#!/usr/bin/env bash
# Smoke tests the deployed API and browser runtime configuration with retries.
# Expects Terraform state available under the selected provider root.
set -euo pipefail

readonly AWS_TF_ROOT="infra/aws"
readonly API_READY_PATH="/health/ready"
readonly UI_HEALTH_PATH="/api/health"
readonly RUNTIME_CONFIG_PATH="/api/runtime-config"
readonly AUTH_CALLBACK_PATH="/auth/callback"
readonly OIDC_DISCOVERY_PATH="/.well-known/openid-configuration"
readonly OAUTH_RESPONSE_TYPE="code"
readonly OAUTH_SCOPES="openid profile email"
readonly PKCE_CHALLENGE_METHOD="S256"
readonly PKCE_VERIFIER_RANDOM_BYTES=48
readonly OAUTH_STATE_RANDOM_BYTES=16
readonly EXPECTED_HTTP_STATUS="200"
readonly OAUTH_ERROR_QUERY_FRAGMENT="error="
readonly GOOGLE_REDIRECT_ERROR_PATTERN='data-error-code="redirect_uri_mismatch"|Error 400: redirect_uri_mismatch'
readonly AWS_IDP_PAGE_SIZE=60
readonly SMOKE_MAX_ATTEMPTS=6
readonly SMOKE_RETRY_DELAY_SECONDS=10
readonly -a AWS_FEDERATED_IDENTITY_PROVIDERS=("Google" "Microsoft")

: "${TF_ROOT:?TF_ROOT must explicitly select a provider root, for example infra/azure or infra/aws.}"
API_URL=$(terraform -chdir="$TF_ROOT" output -raw api_url)
APPLICATION_URL=$(terraform -chdir="$TF_ROOT" output -raw application_url)
echo "::add-mask::$API_URL"
echo "::add-mask::$APPLICATION_URL"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT
command -v openssl >/dev/null 2>&1 || {
  echo "openssl is required to generate ephemeral PKCE values." >&2
  exit 1
}

check_managed_login() {
  local runtime_config authority client_id api_scope authorization_endpoint status provider effective_url
  local pkce_verifier pkce_challenge request_state
  pkce_verifier=$(openssl rand -base64 "$PKCE_VERIFIER_RANDOM_BYTES" \
    | tr '+/' '-_' \
    | tr -d '=\n')
  pkce_challenge=$(printf '%s' "$pkce_verifier" \
    | openssl dgst -sha256 -binary \
    | openssl base64 -A \
    | tr '+/' '-_' \
    | tr -d '=')
  request_state=$(openssl rand -hex "$OAUTH_STATE_RANDOM_BYTES")

  runtime_config=$(curl -fsS "${APPLICATION_URL}${RUNTIME_CONFIG_PATH}")
  authority=$(jq -r '.auth.authority' <<<"$runtime_config")
  client_id=$(jq -r '.auth.clientId' <<<"$runtime_config")
  api_scope=$(jq -r '.auth.apiScope' <<<"$runtime_config")
  authorization_endpoint=$(curl -fsS \
    "${authority}${OIDC_DISCOVERY_PATH}" | jq -r '.authorization_endpoint')

  status=$(curl -sS -L -o "$TEMP_DIR/managed-login.html" -w '%{http_code}' \
    --cookie-jar "$TEMP_DIR/cookies" --cookie "$TEMP_DIR/cookies" \
    --get "$authorization_endpoint" \
    --data-urlencode "client_id=$client_id" \
    --data-urlencode "response_type=$OAUTH_RESPONSE_TYPE" \
    --data-urlencode "redirect_uri=${APPLICATION_URL}${AUTH_CALLBACK_PATH}" \
    --data-urlencode "scope=$OAUTH_SCOPES $api_scope" \
    --data-urlencode "state=$request_state" \
    --data-urlencode "code_challenge=$pkce_challenge" \
    --data-urlencode "code_challenge_method=$PKCE_CHALLENGE_METHOD")

  [[ "$status" == "$EXPECTED_HTTP_STATUS" ]] || return 1

  if [[ "$TF_ROOT" == "$AWS_TF_ROOT" ]]; then
    for provider in "${AWS_FEDERATED_IDENTITY_PROVIDERS[@]}"; do
      status=$(curl -sS -L -o "$TEMP_DIR/${provider}-login.html" \
        -w '%{http_code}' \
        --cookie-jar "$TEMP_DIR/${provider}-cookies" \
        --cookie "$TEMP_DIR/${provider}-cookies" \
        --get "$authorization_endpoint" \
        --data-urlencode "client_id=$client_id" \
        --data-urlencode "response_type=$OAUTH_RESPONSE_TYPE" \
        --data-urlencode "redirect_uri=${APPLICATION_URL}${AUTH_CALLBACK_PATH}" \
        --data-urlencode "scope=$OAUTH_SCOPES $api_scope" \
        --data-urlencode "state=${provider}-${request_state}" \
        --data-urlencode "code_challenge=$pkce_challenge" \
        --data-urlencode "code_challenge_method=$PKCE_CHALLENGE_METHOD" \
        --data-urlencode "identity_provider=$provider")
      [[ "$status" == "$EXPECTED_HTTP_STATUS" ]] || return 1
      if [[ "$provider" == "Google" ]] \
        && rg -qi "$GOOGLE_REDIRECT_ERROR_PATTERN" "$TEMP_DIR/${provider}-login.html"; then
        return 1
      fi

      effective_url=$(curl -sS -L -o /dev/null -w '%{url_effective}' \
        --get "$authorization_endpoint" \
        --data-urlencode "client_id=$client_id" \
        --data-urlencode "response_type=$OAUTH_RESPONSE_TYPE" \
        --data-urlencode "redirect_uri=${APPLICATION_URL}${AUTH_CALLBACK_PATH}" \
        --data-urlencode "scope=$OAUTH_SCOPES $api_scope" \
        --data-urlencode "state=${provider}-${request_state}" \
        --data-urlencode "code_challenge=$pkce_challenge" \
        --data-urlencode "code_challenge_method=$PKCE_CHALLENGE_METHOD" \
        --data-urlencode "identity_provider=$provider")
      [[ "$effective_url" != *"$OAUTH_ERROR_QUERY_FRAGMENT"* ]] || return 1
    done
  fi
}

check_cognito_logout() {
  [[ "$TF_ROOT" == "$AWS_TF_ROOT" ]] || return 0

  local runtime_config logout_endpoint client_id result status effective_url
  runtime_config=$(curl -fsS "${APPLICATION_URL}${RUNTIME_CONFIG_PATH}")
  logout_endpoint=$(jq -r '.auth.logoutEndpoint' <<<"$runtime_config")
  client_id=$(jq -r '.auth.clientId' <<<"$runtime_config")
  result=$(curl -sS -L -o /dev/null -w '%{http_code}\t%{url_effective}' \
    --get "${logout_endpoint}/logout" \
    --data-urlencode "client_id=$client_id" \
    --data-urlencode "logout_uri=$APPLICATION_URL")
  status=${result%%$'\t'*}
  effective_url=${result#*$'\t'}

  [[ "$status" == "$EXPECTED_HTTP_STATUS" ]] || return 1
  [[ "${effective_url%/}" == "${APPLICATION_URL%/}" ]]
}

check_aws_customer_auth() {
  [[ "$TF_ROOT" == "$AWS_TF_ROOT" ]] || return 0

  local user_pool_id client_id identity_providers client
  local expected_federated_providers
  user_pool_id=$(terraform -chdir="$TF_ROOT" output -raw cognito_user_pool_id)
  client_id=$(terraform -chdir="$TF_ROOT" output -raw auth_client_id)
  identity_providers=$(aws cognito-idp list-identity-providers \
    --user-pool-id "$user_pool_id" --max-results "$AWS_IDP_PAGE_SIZE")
  client=$(aws cognito-idp describe-user-pool-client \
    --user-pool-id "$user_pool_id" --client-id "$client_id")
  expected_federated_providers=$(printf '%s\n' "${AWS_FEDERATED_IDENTITY_PROVIDERS[@]}" \
    | jq -R . \
    | jq -sc 'sort')

  jq -e --argjson expected "$expected_federated_providers" \
    '([.Providers[].ProviderName] | sort) == $expected' \
    <<<"$identity_providers" >/dev/null
  jq -e --argjson expected "$expected_federated_providers" \
    '([.UserPoolClient.SupportedIdentityProviders[]] | sort) == $expected' \
    <<<"$client" >/dev/null
}

for ((attempt = 1; attempt <= SMOKE_MAX_ATTEMPTS; attempt++)); do
  if curl -fsS "${API_URL}${API_READY_PATH}" \
    && curl -fsS "${APPLICATION_URL}${UI_HEALTH_PATH}" \
    && curl -fsS "${APPLICATION_URL}${RUNTIME_CONFIG_PATH}" \
    && check_managed_login \
    && check_cognito_logout \
    && check_aws_customer_auth; then
    echo
    echo "API, browser runtime configuration, and required customer authentication ready."
    exit 0
  fi
  echo "Attempt $attempt failed, sleeping ${SMOKE_RETRY_DELAY_SECONDS}s..."
  sleep "$SMOKE_RETRY_DELAY_SECONDS"
done
echo "API, browser runtime configuration, or managed login never returned $EXPECTED_HTTP_STATUS" >&2
exit 1
