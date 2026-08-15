#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# azure-validate-sso-snapshot.sh
#
# Purpose:
#   Closed-loop "gold standard" validation of the Entra External ID
#   customer-SSO bootstrap against live dev + production infrastructure.
#   Consolidates ~20 minutes of ad-hoc CLI (context switching between the
#   workforce subscription and the two External ID tenants, spot-checking
#   Container App env vars, app registrations, and Graph IDP configuration)
#   into a single invocation that emits uniform PASS/FAIL lines and a single
#   process exit code.
#
#   The script runs three sections:
#
#     1. Workforce subscription
#        - Confirms tenant + subscription context.
#        - Reads Authentication__* env vars from the dev and prod API Container Apps
#          to verify the most recent `terraform apply` landed the right values
#          (Authentication__Enabled, Authentication__AllowGuest, Authentication__TenantId, etc.).
#
#     2. Dev External ID tenant
#        - Interactive `az login` to the dev External ID tenant (skipped if
#          already authenticated there).
#        - Runs the Part B health check via azure-verify-deployer-sp.sh.
#        - Lists ea-api-* + ea-spa-* app registrations (Part F snapshot).
#        - Switches to the deployer SP via azure-source-sso-env.sh credentials
#          and reads /beta/identity/identityProviders from Microsoft Graph
#          (Part G snapshot — requires IdentityProvider.Read.All which
#          user-delegated auth lacks, hence the SP switch).
#
#     3. Production External ID tenant
#        - Same shape as Section 2, against the prod tenant.
#
# Usage:
#   # Initial: sign in once to the workforce tenant (hosts the Azure
#   # subscription where Container Apps live).
#   az login
#
#   bash docs/runbooks/scripts/azure-validate-sso-snapshot.sh
#
#   # Safe to gate CI / merges on the exit code:
#   if bash docs/runbooks/scripts/azure-validate-sso-snapshot.sh; then
#     echo "SSO snapshot healthy"
#   fi
#
# Prerequisites:
#   - `az` CLI available on PATH (the script aborts early if not).
#   - `docs/runbooks/scripts/azure-push-sso-secrets.sh` populated (copied from
#     sample.azure-push-sso-secrets.sh and filled in per Part D of the SSO runbook).
#     The deployer-SP client id + secret come from there, via azure-source-sso-env.sh.
#   - An initial `az login` against the workforce tenant. The script sets the
#     configured subscription explicitly before reading Container App env vars.
#   - WORKFORCE_SUBSCRIPTION_ID, WORKFORCE_TENANT_ID,
#     DEV_EXTERNAL_TENANT_ID, and PRODUCTION_EXTERNAL_TENANT_ID loaded from an
#     approved non-repository configuration source.
#
# Behavior notes:
#   - Sections 2 and 3 will run `az login --tenant <external-tenant-id>
#     --allow-no-subscriptions` interactively if the current az session is
#     not already authenticated against that External ID tenant. If the
#     current `az account show --query tenantId -o tsv` already matches the
#     target tenant id, the login step is skipped.
#   - The script does NOT short-circuit on the first failing check. Every
#     section runs to completion so the operator sees the full snapshot in
#     one pass. The only early-abort paths are hard preconditions: missing
#     companion files, no `az login` session, workforce tenant mismatch.
#   - Informational, warning, and error messages go to STDERR. Tabular
#     captures (e.g. `az ad app list ... -o table`) go to STDOUT so the
#     operator can redirect them independently if desired.
#
# Exit codes:
#   0   all checks PASS
#   1   one or more checks FAIL (or a hard precondition is missing); non-zero
#       is safe to gate CI runs or PR merges on.
# -----------------------------------------------------------------------------

set -euo pipefail

# --- deployment identifiers (never committed populated) ----------------------

required_identifier_variables=(
  WORKFORCE_SUBSCRIPTION_ID
  WORKFORCE_TENANT_ID
  DEV_EXTERNAL_TENANT_ID
  PRODUCTION_EXTERNAL_TENANT_ID
)
for variable_name in "${required_identifier_variables[@]}"; do
  [[ -n "${!variable_name:-}" ]] || {
    echo "ERROR: required environment variable is unset: $variable_name" >&2
    exit 2
  }
done

WORKFORCE_SUB="$WORKFORCE_SUBSCRIPTION_ID"
WORKFORCE_TENANT="$WORKFORCE_TENANT_ID"
DEV_EXTERNAL_TENANT="$DEV_EXTERNAL_TENANT_ID"
PROD_EXTERNAL_TENANT="$PRODUCTION_EXTERNAL_TENANT_ID"

# --- repeated fixed strings (hoisted for single-source-of-truth) --------------

APP_API_PREFIX="ea-api"
APP_SPA_PREFIX="ea-spa"
GRAPH_IDP_URL="https://graph.microsoft.com/beta/identity/identityProviders"

# Graph identityProviders are matched by `identityProviderType`, not by `id`.
# Built-in providers have stable ids (EmailOtpSignup-OAUTH, EmailPassword-OAUTH)
# but social providers (Google) have tenant-scoped GUID ids — `identityProviderType`
# is the stable cross-tenant discriminator.
REQUIRED_IDP_TYPES=(EmailOTP EmailPassword Google)

# API Container App coordinates per env (tag-based discovery is unreliable —
# tags have `environment=dev|prod` but no `component` tag, so we address the
# Container Apps by their stable Terraform-produced names directly).
API_APP_NAME_DEV="ea-dev-api"
API_APP_RG_DEV="ea-dev-rg"
API_APP_NAME_PROD="ea-prod-api"
API_APP_RG_PROD="ea-prod-rg"

# --- companion-file paths (absolute; this script is pinned to /workspace) -----

VERIFY_DEPLOYER="/workspace/docs/runbooks/scripts/azure-verify-deployer-sp.sh"
SOURCE_SSO_ENV="/workspace/docs/runbooks/scripts/azure-source-sso-env.sh"
SECRETS_FILE="/workspace/docs/runbooks/scripts/azure-push-sso-secrets.sh"

if [[ ! -f "$VERIFY_DEPLOYER" ]]; then
  echo "ERROR: companion helper not found: $VERIFY_DEPLOYER" >&2
  exit 1
fi
if [[ ! -f "$SOURCE_SSO_ENV" ]]; then
  echo "ERROR: companion helper not found: $SOURCE_SSO_ENV" >&2
  exit 1
fi
if [[ ! -f "$SECRETS_FILE" ]]; then
  echo "ERROR: $SECRETS_FILE not found." >&2
  echo "Copy docs/runbooks/scripts/sample.azure-push-sso-secrets.sh to azure-push-sso-secrets.sh and populate it (see Part D of the SSO runbook)." >&2
  exit 1
fi

if ! command -v az >/dev/null 2>&1; then
  echo "ERROR: 'az' CLI not found on PATH. Install Azure CLI and run 'az login' first." >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: 'jq' not found on PATH. Install jq and retry." >&2
  exit 1
fi

# --- fail tracker -------------------------------------------------------------

fail_count=0

pass() {
  echo "  PASS: $*" >&2
}

fail() {
  echo "  FAIL: $*" >&2
  fail_count=$((fail_count + 1))
}

section() {
  echo >&2
  echo "=== $* ===" >&2
}

# ============================================================================
# Section 1 — Workforce subscription
# ============================================================================

section "Section 1: workforce subscription context + Container Apps env vars"

if ! az account set --subscription "$WORKFORCE_SUB" >/dev/null 2>&1; then
  echo "  FAIL: unable to 'az account set --subscription $WORKFORCE_SUB'." >&2
  echo "        Run 'az login' against the workforce tenant ($WORKFORCE_TENANT) and retry." >&2
  exit 1
fi

current_tid="$(az account show --query tenantId -o tsv 2>/dev/null || echo "")"
if [[ "$current_tid" != "$WORKFORCE_TENANT" ]]; then
  echo "  FAIL: active tenant is '$current_tid'; expected workforce tenant '$WORKFORCE_TENANT'." >&2
  echo "        Run: az login --tenant $WORKFORCE_TENANT" >&2
  exit 1
fi
pass "workforce subscription + tenant context ($WORKFORCE_SUB / $WORKFORCE_TENANT)"

# Helper: verify Authentication__* env block on a given environment's API Container App.
# $1 = env tag value (dev|production)
# $2 = expected string value of Authentication__AllowDev
# $3 = expected string value of Authentication__AllowGuest
check_containerapp_env() {
  local env="$1"
  local expect_allow_dev="$2"
  local expect_allow_guest="$3"

  local expected_tenant
  if [[ "$env" == "dev" ]]; then
    expected_tenant="$DEV_EXTERNAL_TENANT"
  else
    expected_tenant="$PROD_EXTERNAL_TENANT"
  fi

  echo >&2
  echo "--- $env API Container App ---" >&2

  local app_name app_rg
  if [[ "$env" == "dev" ]]; then
    app_name="$API_APP_NAME_DEV"
    app_rg="$API_APP_RG_DEV"
  else
    app_name="$API_APP_NAME_PROD"
    app_rg="$API_APP_RG_PROD"
  fi

  echo "  expected: Container App '$app_name' exists in resource group '$app_rg'" >&2
  if az containerapp show --name "$app_name" --resource-group "$app_rg" --query name -o tsv >/dev/null 2>&1; then
    echo "  actual:   Container App '$app_name' found in '$app_rg'" >&2
    pass "$env API Container App located ($app_name in $app_rg)"
  else
    echo "  actual:   Container App '$app_name' NOT found in '$app_rg'" >&2
    fail "$env API Container App not found ($app_name in $app_rg)"
    return
  fi

  local env_json
  env_json="$(az containerapp show \
    --name "$app_name" \
    --resource-group "$app_rg" \
    --query "properties.template.containers[0].env[?starts_with(name,'Authentication__')]" \
    -o json 2>/dev/null || echo "[]")"

  # Helper to pull a single Authentication__X value (empty string if absent).
  local authentication_enabled authentication_provider authentication_allow_dev authentication_allow_guest authentication_authority authentication_audience authentication_client_id
  authentication_enabled="$(jq -r '[.[] | select(.name=="Authentication__Enabled")][0].value // ""'       <<<"$env_json")"
  authentication_provider="$(jq -r '[.[] | select(.name=="Authentication__Provider")][0].value // ""'     <<<"$env_json")"
  authentication_allow_dev="$(jq -r '[.[] | select(.name=="Authentication__AllowDev")][0].value // ""'     <<<"$env_json")"
  authentication_allow_guest="$(jq -r '[.[] | select(.name=="Authentication__AllowGuest")][0].value // ""' <<<"$env_json")"
  authentication_authority="$(jq -r '[.[] | select(.name=="Authentication__Authority")][0].value // ""'   <<<"$env_json")"
  authentication_audience="$(jq -r '[.[] | select(.name=="Authentication__Audience")][0].value // ""'     <<<"$env_json")"
  authentication_client_id="$(jq -r '[.[] | select(.name=="Authentication__ClientId")][0].value // ""'    <<<"$env_json")"

  echo "  expected: Authentication__Enabled = true" >&2
  echo "  actual:   Authentication__Enabled = '$authentication_enabled'" >&2
  if [[ "$authentication_enabled" == "true" ]]; then
    pass "$env Authentication__Enabled = true"
  else
    fail "$env Authentication__Enabled = '$authentication_enabled' (expected 'true')"
  fi

  echo "  expected: Authentication__Provider = entra" >&2
  echo "  actual:   Authentication__Provider = '$authentication_provider'" >&2
  if [[ "$authentication_provider" == "entra" ]]; then
    pass "$env Authentication__Provider = entra"
  else
    fail "$env Authentication__Provider = '$authentication_provider' (expected 'entra')"
  fi

  echo "  expected: Authentication__AllowDev = $expect_allow_dev" >&2
  echo "  actual:   Authentication__AllowDev = '$authentication_allow_dev'" >&2
  if [[ "$authentication_allow_dev" == "$expect_allow_dev" ]]; then
    pass "$env Authentication__AllowDev = $expect_allow_dev"
  else
    fail "$env Authentication__AllowDev = '$authentication_allow_dev' (expected '$expect_allow_dev')"
  fi

  echo "  expected: Authentication__AllowGuest = $expect_allow_guest" >&2
  echo "  actual:   Authentication__AllowGuest = '$authentication_allow_guest'" >&2
  if [[ "$authentication_allow_guest" == "$expect_allow_guest" ]]; then
    pass "$env Authentication__AllowGuest = $expect_allow_guest"
  else
    fail "$env Authentication__AllowGuest = '$authentication_allow_guest' (expected '$expect_allow_guest')"
  fi

  echo "  expected: Authentication__Authority ~ https://<tenant-subdomain>.ciamlogin.com/<external-tenant-id>/v2.0/" >&2
  echo "  actual:   Authentication__Authority = '$authentication_authority'" >&2
  if [[ "$authentication_authority" == *"$expected_tenant"* ]]; then
    pass "$env Authentication__Authority contains the expected tenant"
  else
    fail "$env Authentication__Authority does not contain '$expected_tenant'"
  fi

  echo "  expected: Authentication__Audience ~ api://<api-app-client-id>" >&2
  echo "  actual:   Authentication__Audience = '$authentication_audience'" >&2
  if [[ -n "$authentication_audience" ]]; then
    pass "$env Authentication__Audience present"
  else
    fail "$env Authentication__Audience is empty"
  fi

  echo "  expected: Authentication__ClientId = <api-app-client-id-guid>" >&2
  echo "  actual:   Authentication__ClientId = '$authentication_client_id'" >&2
  if [[ -n "$authentication_client_id" ]]; then
    pass "$env Authentication__ClientId present"
  else
    fail "$env Authentication__ClientId is empty"
  fi

}

check_containerapp_env dev true false
check_containerapp_env production false false

# ============================================================================
# Sections 2 + 3 — External ID tenants (shared helper)
# ============================================================================

# $1 = env (dev|production)
# $2 = target External ID tenant id (GUID)
check_external_id_tenant() {
  local env="$1"
  local tenant_id="$2"

  section "Section for $env External ID tenant ($tenant_id)"

  # --- login (skip if already there) ---
  local current
  current="$(az account show --query tenantId -o tsv 2>/dev/null || echo "")"
  if [[ "$current" == "$tenant_id" ]]; then
    echo "  expected: az account show --query tenantId -o tsv == $tenant_id" >&2
    echo "  actual:   az tenantId = '$current'" >&2
    pass "$env tenant: az session already on $tenant_id (login skipped)"
  else
    echo "  Signing in to $env External ID tenant $tenant_id (interactive)..." >&2
    if ! az login --tenant "$tenant_id" --allow-no-subscriptions >/dev/null; then
      local current_after
      current_after="$(az account show --query tenantId -o tsv 2>/dev/null || echo "")"
      echo "  expected: az account show --query tenantId -o tsv == $tenant_id" >&2
      echo "  actual:   az tenantId = '$current_after'" >&2
      fail "$env tenant: az login failed (tenant $tenant_id)"
      return
    fi
    local current_after
    current_after="$(az account show --query tenantId -o tsv 2>/dev/null || echo "")"
    echo "  expected: az account show --query tenantId -o tsv == $tenant_id" >&2
    echo "  actual:   az tenantId = '$current_after'" >&2
    pass "$env tenant: az login succeeded ($tenant_id)"
  fi

  # --- Part B: deployer SP health rollup ---
  echo >&2
  echo "--- $env deployer SP health (azure-verify-deployer-sp.sh) ---" >&2
  local rc=0
  bash "$VERIFY_DEPLOYER" "$env" >&2 || rc=$?
  echo "  expected: azure-verify-deployer-sp.sh $env → exit 0 (audience single-tenant, >=1 live secret, 3 required Graph roles admin-consented)" >&2
  echo "  actual:   azure-verify-deployer-sp.sh $env → exit=$rc" >&2
  if (( rc == 0 )); then
    pass "$env deployer SP health"
  else
    fail "$env deployer SP health"
  fi

  # --- Part F: app registrations snapshot ---
  echo >&2
  echo "--- $env app registrations (ea-api-* + ea-spa-*) ---" >&2
  # Positive-only filter: do NOT use `!starts_with(...)` — '!' inside a
  # double-quoted arg triggers bash history expansion in interactive shells.
  az ad app list \
    --filter "startswith(displayName,'$APP_API_PREFIX') or startswith(displayName,'$APP_SPA_PREFIX')" \
    --query "[].{name:displayName, appId:appId, audience:signInAudience}" \
    -o table || true

  local api_count spa_count
  api_count="$(az ad app list \
    --filter "startswith(displayName,'$APP_API_PREFIX')" \
    --query "length([])" -o tsv 2>/dev/null || echo "0")"
  spa_count="$(az ad app list \
    --filter "startswith(displayName,'$APP_SPA_PREFIX')" \
    --query "length([])" -o tsv 2>/dev/null || echo "0")"

  echo "  expected: ${APP_API_PREFIX}-* app registrations, count >= 1" >&2
  echo "  actual:   count=$api_count" >&2
  if [[ "${api_count:-0}" =~ ^[0-9]+$ ]] && (( api_count >= 1 )); then
    pass "$env ea-api-* app registrations found (count=$api_count)"
  else
    fail "$env ea-api-* app registrations not found (count=${api_count:-0})"
  fi

  echo "  expected: ${APP_SPA_PREFIX}-* app registrations, count >= 1" >&2
  echo "  actual:   count=$spa_count" >&2
  if [[ "${spa_count:-0}" =~ ^[0-9]+$ ]] && (( spa_count >= 1 )); then
    pass "$env ea-spa-* app registrations found (count=$spa_count)"
  else
    fail "$env ea-spa-* app registrations not found (count=${spa_count:-0})"
  fi

  # --- Part G: Graph IDPs (requires deployer SP auth) ---
  echo >&2
  echo "--- $env Graph identityProviders (via deployer SP) ---" >&2

  local sso_exports
  if ! sso_exports="$(bash "$SOURCE_SSO_ENV" "$env" 2>/dev/null)"; then
    fail "$env Graph IDPs: azure-source-sso-env.sh failed for env=$env"
    return
  fi
  # Evaluate in a subshell-scoped way — we still need the vars for az login.
  # shellcheck disable=SC1090
  eval "$sso_exports"

  if [[ -z "${TF_VAR_external_tenant_client_id:-}" || -z "${TF_VAR_external_tenant_client_secret:-}" ]]; then
    fail "$env Graph IDPs: deployer SP credentials empty after azure-source-sso-env.sh"
    return
  fi

  if ! az login \
      --service-principal \
      --username "$TF_VAR_external_tenant_client_id" \
      --password "$TF_VAR_external_tenant_client_secret" \
      --tenant "$tenant_id" \
      --allow-no-subscriptions >/dev/null 2>&1; then
    echo "  expected: deployer SP login to $tenant_id → success" >&2
    echo "  actual:   deployer SP login returned exit non-zero" >&2
    fail "$env Graph IDPs: az login --service-principal failed for tenant $tenant_id"
    return
  fi
  echo "  expected: deployer SP login to $tenant_id → success" >&2
  echo "  actual:   deployer SP login returned exit 0" >&2
  pass "$env Graph IDPs: authenticated as deployer SP"

  local idp_json
  if ! idp_json="$(az rest --method get \
      --uri "$GRAPH_IDP_URL" \
      --query "value[].{id:id, name:displayName, type:\"@odata.type\", identityProviderType:identityProviderType}" \
      -o json 2>/dev/null)"; then
    fail "$env Graph IDPs: /beta/identity/identityProviders fetch failed"
    return
  fi

  # Echo a readable list to stderr for snapshot detail.
  echo "  Identity providers present in $env tenant:" >&2
  jq -r '.[] | "  - \(.identityProviderType)  (\(.name), id=\(.id))"' <<<"$idp_json" >&2 || true

  local idp_actual_types
  idp_actual_types="$(jq -r 'map(.identityProviderType) | join(",")' <<<"$idp_json")"
  local idp_type
  for idp_type in "${REQUIRED_IDP_TYPES[@]}"; do
    echo "  expected: Graph identityProviderType='$idp_type' present" >&2
    echo "  actual:   identityProviderTypes=$idp_actual_types" >&2
    if jq -e --arg n "$idp_type" 'any(.[]; .identityProviderType == $n)' <<<"$idp_json" >/dev/null; then
      pass "$env Graph IDP present: identityProviderType=$idp_type"
    else
      fail "$env Graph IDP missing: identityProviderType=$idp_type"
    fi
  done
}

check_external_id_tenant dev        "$DEV_EXTERNAL_TENANT"
check_external_id_tenant production "$PROD_EXTERNAL_TENANT"

# ============================================================================
# Final summary
# ============================================================================

echo >&2
if (( fail_count == 0 )); then
  echo "SNAPSHOT: all checks PASS" >&2
  exit 0
else
  echo "SNAPSHOT: $fail_count check(s) FAILED" >&2
  exit 1
fi
