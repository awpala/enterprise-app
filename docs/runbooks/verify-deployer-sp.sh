#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# verify-deployer-sp.sh
#
# Purpose:
#   Post-Part-B health check on the `ea-terraform-deployer` service principal
#   inside an Entra External ID tenant. Verifies:
#     1. The app registration exists.
#     2. It is single-tenant (`AzureADMyOrg`).
#     3. At least one unexpired client secret is present.
#     4. The three required Microsoft Graph application roles are
#        assigned + admin-consented:
#          - Application.ReadWrite.All
#          - IdentityProvider.ReadWrite.All
#          - Policy.ReadWrite.AuthenticationFlows
#
# Usage:
#   # First time only: sign in to the target External ID tenant.
#   az login --tenant <external-tenant-id> --allow-no-subscriptions
#   bash docs/runbooks/verify-deployer-sp.sh <dev|production>
#
# Re-run this any time the deployer SP's secret is rotated
# (docs/runbooks/sso-manual-bootstrap.md §11) or when CI begins failing
# with `Authorization_RequestDenied` / `Insufficient privileges` on
# External ID apply.
#
# Exits non-zero on any check failure; safe to chain into CI or
# pre-apply gating.
# -----------------------------------------------------------------------------

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <dev|production>" >&2
  exit 1
fi

ENV="$1"
case "$ENV" in
  dev)        TENANT_ID="a400a39c-97cf-4459-932e-6dfccf2adf1c" ;;
  production) TENANT_ID="8ce01097-ed0b-4425-a49a-2f42c41a1119" ;;
  *) echo "Unknown environment '$ENV' (expected 'dev' or 'production')." >&2; exit 1 ;;
esac

# Preflight: az must be signed into the target tenant. External ID tenants
# typically have no linked Azure subscription, so --allow-no-subscriptions
# is expected on the upstream `az login` call.
current_tid=$(az account show --query tenantId -o tsv 2>/dev/null || echo "")
if [[ "$current_tid" != "$TENANT_ID" ]]; then
  echo "ERROR: az is currently signed in to tenant '$current_tid'." >&2
  echo "       Expected tenant '$TENANT_ID' ($ENV External ID)." >&2
  echo "       Run: az login --tenant $TENANT_ID --allow-no-subscriptions" >&2
  exit 1
fi

echo "=== Verifying ea-terraform-deployer in tenant $TENANT_ID ($ENV) ==="
echo

# --- App registration ---
app_json=$(az ad app list --filter "displayName eq 'ea-terraform-deployer'" --query "[0]" -o json)
if [[ -z "$app_json" || "$app_json" == "null" ]]; then
  echo "FAIL: no 'ea-terraform-deployer' app registration found in this tenant." >&2
  exit 1
fi

app_id=$(jq -r '.appId'           <<<"$app_json")
audience=$(jq -r '.signInAudience' <<<"$app_json")

echo "App (client) ID : $app_id"
echo "signInAudience  : $audience"

if [[ "$audience" != "AzureADMyOrg" ]]; then
  echo "  WARN: audience should be 'AzureADMyOrg' (single-tenant) for a CI deployer SP; got '$audience'."
fi

# --- Client secrets ---
echo
echo "--- Client secrets ---"
now_epoch=$(date -u +%s)
has_live_secret=0
while IFS=$'\t' read -r label end_iso; do
  end_epoch=$(date -u -d "$end_iso" +%s 2>/dev/null || echo 0)
  days_left=$(( (end_epoch - now_epoch) / 86400 ))
  label_display="${label:-<unlabelled>}"
  if (( days_left > 0 )); then
    has_live_secret=1
    status="ok"
    if (( days_left < 30 )); then status="expiring in $days_left day(s)"; fi
    echo "  [$status] $label_display  ends $end_iso"
  else
    echo "  [EXPIRED] $label_display  ends $end_iso"
  fi
done < <(jq -r '.passwordCredentials[] | [(.displayName // ""), .endDateTime] | @tsv' <<<"$app_json")

if (( has_live_secret == 0 )); then
  echo "FAIL: no unexpired client secret on the deployer SP." >&2
  exit 1
fi

# --- Graph app-role assignments (admin consent status) ---
echo
echo "--- Graph app-role assignments ---"

sp_obj=$(az ad sp list --filter "appId eq '$app_id'" --query "[0].id" -o tsv)
if [[ -z "$sp_obj" ]]; then
  echo "FAIL: deployer SP has no service principal object (app reg created but SP never materialized)." >&2
  exit 1
fi

# Microsoft Graph's own SP — its object ID is the resourceId we match on.
graph_app_id="00000003-0000-0000-c000-000000000000"
graph_sp=$(az ad sp list --filter "appId eq '$graph_app_id'" --query "[0].id" -o tsv)

# Map of Graph appRole id -> friendly name (for the full catalog, then we
# filter to only what the deployer has).
graph_app_roles=$(az rest --method get \
  --uri "https://graph.microsoft.com/v1.0/servicePrincipals/$graph_sp" \
  --query "appRoles[].{id:id, name:value}" -o json)

assigned_ids=$(az rest --method get \
  --uri "https://graph.microsoft.com/v1.0/servicePrincipals/$sp_obj/appRoleAssignments" \
  --query "value[?resourceId=='$graph_sp'].appRoleId" -o json)

assigned_names=$(jq -n \
  --argjson roles "$graph_app_roles" \
  --argjson ids   "$assigned_ids" \
  '$ids | map(. as $id | $roles[] | select(.id == $id) | .name) | sort')

echo "Assigned:"
jq -r '.[]' <<<"$assigned_names" | sed 's/^/  - /'

required=(Application.ReadWrite.All IdentityProvider.ReadWrite.All Policy.ReadWrite.AuthenticationFlows)
missing=0
for name in "${required[@]}"; do
  if ! jq -e --arg n "$name" 'index($n) != null' <<<"$assigned_names" >/dev/null; then
    echo "  MISSING: $name"
    missing=1
  fi
done

echo
if (( missing != 0 )); then
  echo "FAIL: one or more required Graph app roles are not admin-consented on the deployer SP." >&2
  echo "      Fix: Entra ID -> App registrations -> ea-terraform-deployer -> API permissions" >&2
  echo "            -> + Add a permission -> Microsoft Graph -> Application permissions," >&2
  echo "            then 'Grant admin consent for <tenant>' on the missing role(s)." >&2
  exit 1
fi

echo "All checks passed for $ENV."
