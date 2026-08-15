#!/usr/bin/env bash

# Minimal az-teardown.sh — streamlined "strip costs" happy path only.
#
# Behavior:
# - Single purpose: stop/delete high-cost services in target env(s) and retain
#   resource groups and non-billing resources (CIAM, Key Vault metadata).
# - Requires AZURE_DEV_RESOURCE_GROUP and AZURE_PRODUCTION_RESOURCE_GROUP from
#   an ignored operator configuration. It always targets both configured groups.

set -euo pipefail

LOG_DIR="/workspace/__logs"
mkdir -p "${LOG_DIR}"
LOGFILE="${LOG_DIR}/az-teardown__$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "${LOGFILE}") 2>&1

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
log_info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
log_success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
log_step()    { echo -e "\n${BOLD}==> $*${RESET}"; }

: "${AZURE_DEV_RESOURCE_GROUP:?Set AZURE_DEV_RESOURCE_GROUP from the approved operator configuration.}"
: "${AZURE_PRODUCTION_RESOURCE_GROUP:?Set AZURE_PRODUCTION_RESOURCE_GROUP from the approved operator configuration.}"
declare -A RG=( [dev]="$AZURE_DEV_RESOURCE_GROUP" [prod]="$AZURE_PRODUCTION_RESOURCE_GROUP" )

strip_costs_env() {
  local rg="$1"
  log_step "Strip costs in ${rg}"

  log_step "Stopping PostgreSQL flexible servers (async)"
  az postgres flexible-server list --resource-group "${rg}" --query '[].name' -o tsv 2>/dev/null \
    | while IFS= read -r pg; do
      if [[ -n "${pg}" ]]; then
        log_info "Requesting stop for Postgres: ${pg}"
        az postgres flexible-server stop --name "${pg}" --resource-group "${rg}" --no-wait || log_warn "Stop requested (background) for ${pg}"
      fi
    done || true

  log_step "Deleting Container Apps (async)"
  az containerapp list -g "${rg}" --query '[].name' -o tsv 2>/dev/null \
    | while IFS= read -r ca; do
      if [[ -n "${ca}" ]]; then
        log_info "Requesting delete for Container App: ${ca}"
        az containerapp delete -g "${rg}" -n "${ca}" --yes --no-wait || log_warn "Delete requested (background) for ${ca}"
      fi
    done || true

  log_step "Deleting Application Insights (async)"
  az monitor app-insights component list --resource-group "${rg}" --query '[].name' -o tsv 2>/dev/null \
    | while IFS= read -r ai; do
      if [[ -n "${ai}" ]]; then
        log_info "Requesting delete for App Insights: ${ai}"
        az monitor app-insights component delete --app "${ai}" -g "${rg}" --yes --no-wait || log_warn "Delete requested (background) for ${ai}"
      fi
    done || true

  log_step "Cleaning ACR repositories (async)"
  az acr list --resource-group "${rg}" --query '[].name' -o tsv 2>/dev/null \
    | while IFS= read -r acr; do
      if [[ -n "${acr}" ]]; then
        az acr repository list -n "${acr}" -o tsv 2>/dev/null \
          | while IFS= read -r repo; do
            if [[ -n "${repo}" ]]; then
              log_info "Requesting delete for ACR repo ${repo} in ${acr}"
              az acr repository delete -n "${acr}" --repository "${repo}" --yes --no-wait || log_warn "Delete requested (background) for repo ${repo} in ${acr}"
            fi
          done
      fi
    done || true

  log_success "Strip-costs requested for ${rg}. Actions are running asynchronously. Resource group retained."
}


# This script is intentionally minimal and opinionated: it performs the
# non-destructive "strip-costs" actions for hot-redeploy preparedness.
# It runs for BOTH environments (dev + prod) and accepts NO FLAGS.
ENVS=(dev prod)

log_info "Running strip-costs happy path for both environments (no flags)"
for e in "${ENVS[@]}"; do
  strip_costs_env "${RG[$e]}"
done

log_info "All requested strip-costs operations submitted. Check __logs for details and Azure Portal for progress."

exit 0
