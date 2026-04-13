#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# plan-infra.sh
#
# Purpose:
#   One-command wrapper around the local Terraform plan workflow for the root
#   `infra/` module. Replaces the multi-step "eval source-sso-env + az account
#   show + cd infra + terraform init + terraform plan" sequence documented in
#   Section 8 (Part F) of docs/runbooks/sso-manual-bootstrap.md. Targets a
#   single environment per invocation — `dev` or `production`.
#
# Usage:
#   bash docs/runbooks/plan-infra.sh dev
#   bash docs/runbooks/plan-infra.sh production
#
#   # Save the plan binary for a later `terraform apply <file>`:
#   bash docs/runbooks/plan-infra.sh dev --out /tmp/dev.tfplan
#   bash docs/runbooks/plan-infra.sh production -o /tmp/prod.tfplan
#
#   Runnable from any working directory — the script resolves its own
#   location and `cd`s into /workspace/infra internally.
#
# Prerequisites:
#   - docs/runbooks/push-sso-secrets.sh populated (copied from
#     sample.push-sso-secrets.sh and filled in per Part D of the SSO runbook).
#     This script reuses source-sso-env.sh — the single source of truth for
#     exporting TF_VAR_* from that populated file. Nothing is duplicated here.
#   - `az login` completed against the workforce tenant, so the AzureRM and
#     AzureAD providers can initialize and `az account show` can resolve the
#     active subscription.
#
# Refresh policy:
#   This script passes `-refresh=false` to `terraform plan` by default. The
#   rationale: local preview is an advisory, read-only sanity check; refresh
#   requires the operator's `az login` identity to already hold every
#   data-source read permission — including KV Secrets and every other data
#   block the root module touches — which is a higher bar than what "just
#   previewing a plan" warrants. CI still does a full apply with refresh
#   because it runs under the platform SP, which holds those grants. To
#   force a refresh locally, run terraform from `infra/` by hand.
#
# What to check in the plan output (clean first-run expectations):
#   - `module.entra_external_id.*` resources all appear as additions
#     (app registrations, user flow, Google/Microsoft/Email IDP wiring).
#   - `module.container_apps.*` updates where the API container app gains
#     new `AzureAd__*` environment variables wired from the External ID
#     module outputs.
#   - Zero unexpected destroys — especially none outside
#     `module.entra_external_id`. If you see unrelated destroys, STOP and
#     investigate (likely state drift, not expected change).
#
# Exit codes:
#   0   plan completed (review adds/changes/destroys above)
#   1   argument validation, missing az login, missing push-sso-secrets.sh,
#       or terraform step failure — stderr carries the specific diagnostic.
# -----------------------------------------------------------------------------

set -euo pipefail

# ---- arg parsing ------------------------------------------------------------

usage() {
  cat >&2 <<'USAGE'
Usage: plan-infra.sh <dev|production> [--out <file> | -o <file>]

Examples:
  bash docs/runbooks/plan-infra.sh dev
  bash docs/runbooks/plan-infra.sh production --out /tmp/prod.tfplan
USAGE
}

if [[ $# -lt 1 ]]; then
  echo "Error: missing required <env> positional argument." >&2
  usage
  exit 1
fi

ENV="$1"
shift

if [[ "$ENV" != "dev" && "$ENV" != "production" ]]; then
  echo "Error: invalid env '$ENV' — expected 'dev' or 'production'." >&2
  usage
  exit 1
fi

OUT_FILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --out|-o)
      if [[ $# -lt 2 ]]; then
        echo "Error: $1 requires a file path argument." >&2
        usage
        exit 1
      fi
      OUT_FILE="$2"
      shift 2
      ;;
    *)
      echo "Error: unrecognized argument '$1'." >&2
      usage
      exit 1
      ;;
  esac
done

# ---- resolve paths ----------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_SSO_ENV="$SCRIPT_DIR/source-sso-env.sh"
SECRETS="$SCRIPT_DIR/push-sso-secrets.sh"
INFRA_DIR="$(cd "$SCRIPT_DIR/../../infra" && pwd)"

if [[ ! -f "$SOURCE_SSO_ENV" ]]; then
  echo "Error: companion helper not found: $SOURCE_SSO_ENV" >&2
  exit 1
fi

if [[ ! -f "$SECRETS" ]]; then
  echo "Error: $SECRETS not found." >&2
  echo "Copy docs/runbooks/sample.push-sso-secrets.sh to push-sso-secrets.sh and populate it (see Part D of the SSO runbook)." >&2
  exit 1
fi

# ---- export TF_VAR_* via the single-source helper --------------------------

echo "Exporting TF_VAR_* for env=$ENV via source-sso-env.sh..." >&2
# Reuse source-sso-env.sh verbatim — it is the single place that knows how to
# extract values from push-sso-secrets.sh.
SSO_EXPORTS="$(bash "$SOURCE_SSO_ENV" "$ENV")"
eval "$SSO_EXPORTS"

# ---- resolve subscription via az --------------------------------------------

if ! command -v az >/dev/null 2>&1; then
  echo "Error: 'az' CLI not found on PATH. Install Azure CLI and run 'az login' first." >&2
  exit 1
fi

echo "Resolving active Azure subscription via 'az account show'..." >&2
if ! SUBSCRIPTION_ID="$(az account show --query id -o tsv 2>/dev/null)"; then
  echo "Error: 'az account show' failed — run 'az login' against the workforce tenant and retry." >&2
  exit 1
fi

if [[ -z "$SUBSCRIPTION_ID" ]]; then
  echo "Error: resolved subscription id was empty — run 'az login' and 'az account set' to select the target subscription." >&2
  exit 1
fi

# ---- terraform init + plan --------------------------------------------------

cd "$INFRA_DIR"

BACKEND_KEY="${ENV}.tfstate"

echo "Running 'terraform init -upgrade' against backend key=$BACKEND_KEY..." >&2
if ! terraform init -upgrade \
  -backend-config=resource_group_name=ea-tfstate-rg \
  -backend-config=storage_account_name=eatfstateeaboot \
  -backend-config=container_name=tfstate \
  -backend-config="key=$BACKEND_KEY"; then
  echo "Error: 'terraform init' failed — inspect output above." >&2
  exit 1
fi

PLAN_ARGS=(
  "-refresh=false"
  "-var-file=envs/${ENV}.tfvars"
  "-var" "subscription_id=$SUBSCRIPTION_ID"
)

if [[ -n "$OUT_FILE" ]]; then
  PLAN_ARGS+=("-out=$OUT_FILE")
  echo "Running 'terraform plan' with -refresh=false -out=$OUT_FILE..." >&2
else
  echo "Running 'terraform plan' (read-only preview, -refresh=false — no binary saved)..." >&2
fi

if ! terraform plan "${PLAN_ARGS[@]}"; then
  echo "Error: 'terraform plan' failed — inspect output above." >&2
  exit 1
fi

echo "Plan complete — review adds/changes/destroys above." >&2
