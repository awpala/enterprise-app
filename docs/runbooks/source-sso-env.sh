#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# source-sso-env.sh
#
# Purpose:
#   Emit `export TF_VAR_*=...` statements for the two External-ID SP credential
#   values required by `terraform plan`/`terraform apply` in `infra/`. Enables
#   local Terraform runs that mirror the secret variables the CI pipeline
#   injects from GitHub Environment secrets.
#
#   Non-secret tenant identifiers (external_tenant_id, tenant_subdomain) are
#   NOT exported here — they now live in infra/envs/<env>.tfvars directly,
#   because -var-file has higher precedence than TF_VAR_* env vars, and
#   committing a tenant GUID + subdomain is safe (they are not credentials).
#
# Usage:
#   eval "$(bash docs/runbooks/source-sso-env.sh dev)"
#   eval "$(bash docs/runbooks/source-sso-env.sh production)"
#
#   Then:
#     cd infra && terraform plan
#
# Design notes:
#   - Single source of truth: this helper reuses the already-populated,
#     gitignored `docs/runbooks/push-sso-secrets.sh` (copied from
#     `sample.push-sso-secrets.sh`). The operator populates secret values
#     exactly once — there. No duplicated populate step here.
#   - This file itself contains NO secrets and is safe to commit (tracked).
#   - Safe to run multiple times; it is a pure read + transform.
#   - Output contract: `export TF_VAR_*` lines are written to STDOUT only.
#     All informational, warning, and error messages go to STDERR so that
#     `eval "$(...)"` never sees noise on stdout.
#   - The sourced `push-sso-secrets.sh` normally runs `gh secret set` /
#     `gh variable set` to push values to GitHub. We don't want those network
#     side effects here — we only want the variable values resolved — so we
#     stub `gh` to a no-op inside the subshell that sources the script.
# -----------------------------------------------------------------------------

set -euo pipefail

ENV="${1:-}"
if [[ "$ENV" != "dev" && "$ENV" != "production" ]]; then
  echo "Usage: source-sso-env.sh <dev|production>" >&2
  echo "  eval \"\$(bash docs/runbooks/source-sso-env.sh dev)\"" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRETS="$SCRIPT_DIR/push-sso-secrets.sh"

if [[ ! -f "$SECRETS" ]]; then
  echo "Error: $SECRETS not found." >&2
  echo "Copy docs/runbooks/sample.push-sso-secrets.sh to push-sso-secrets.sh and populate it first." >&2
  exit 1
fi

# Subshell:
#   - Stub `gh` as a no-op so the sourced script's `gh secret set` /
#     `gh variable set` calls don't fire (no network side effects).
#   - Redirect the sourced script's own stdout to stderr so its informational
#     echoes ("Pushing SSO values..." / "Done — ...") don't pollute our stdout.
#   - Emit the two `export TF_VAR_*` lines on stdout — the caller's `eval`
#     consumes exactly these.
(
  gh() { :; }
  # shellcheck disable=SC1090
  source "$SECRETS" "$ENV" >&2

  cat <<EXPORTS
export TF_VAR_external_tenant_client_id="$EXTERNAL_TENANT_CLIENT_ID"
export TF_VAR_external_tenant_client_secret="$EXTERNAL_TENANT_CLIENT_SECRET"
export TF_VAR_google_oidc_client_id="$GOOGLE_OIDC_CLIENT_ID"
export TF_VAR_google_oidc_client_secret="$GOOGLE_OIDC_CLIENT_SECRET"
EXPORTS
)

echo "Exported TF_VAR_* External-ID SP credentials for ENV=$ENV" >&2
