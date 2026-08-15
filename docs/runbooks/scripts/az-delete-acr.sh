#!/usr/bin/env bash

# az-delete-acr.sh — explicitly delete only the configured Azure registries.
#
# This is a destructive, narrowly scoped maintenance helper, not a declaration
# of current account cost. Confirm the live Cost Management inventory before
# use. Resource groups are retained because they may contain customer identity
# resources and other state that a blanket group delete would destroy.
#
# Terraform: both registries exist in state as module.acr.azurerm_container_registry.this.
# No `terraform state rm` is performed — a later `terraform apply` will refresh,
# observe the registry is gone, and plan to recreate it. That is the desired
# relaunch behavior. Relaunch also requires rebuilding and pushing images,
# since the stored image tags are deleted with the registry.
#
# Required configuration (load from an ignored operator config):
#   AZURE_SUBSCRIPTION_ID
#   AZURE_ACR_TARGETS="<registry>:<resource-group> [<registry>:<resource-group> ...]"
#
# Usage:
#   ./az-delete-acr.sh              # delete
#   ./az-delete-acr.sh --dry-run    # show what would be deleted, change nothing

set -euo pipefail

LOG_DIR="/workspace/__logs"
mkdir -p "${LOG_DIR}"
LOGFILE="${LOG_DIR}/az-delete-acr__$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "${LOGFILE}") 2>&1

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
log_info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${RESET} $*"; }
log_success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
log_step()    { echo -e "\n${BOLD}==> $*${RESET}"; }

: "${AZURE_SUBSCRIPTION_ID:?Set AZURE_SUBSCRIPTION_ID from the approved operator configuration.}"
: "${AZURE_ACR_TARGETS:?Set AZURE_ACR_TARGETS as space-separated registry:resource-group pairs.}"
SUBSCRIPTION_ID="$AZURE_SUBSCRIPTION_ID"
read -r -a TARGETS <<<"$AZURE_ACR_TARGETS"
for target in "${TARGETS[@]}"; do
  [[ "$target" =~ ^[^:[:space:]]+:[^:[:space:]]+$ ]] || {
    log_error "Invalid AZURE_ACR_TARGETS entry: $target"
    exit 2
  }
done

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

log_step "Preflight"
CURRENT_SUB="$(az account show --query id -o tsv)"
if [[ "${CURRENT_SUB}" != "${SUBSCRIPTION_ID}" ]]; then
  log_error "Active subscription ${CURRENT_SUB} != expected ${SUBSCRIPTION_ID}. Aborting."
  exit 1
fi
log_success "Subscription ${CURRENT_SUB}"

log_step "Registries targeted for deletion"
FOUND=()
for t in "${TARGETS[@]}"; do
  acr="${t%%:*}"; rg="${t##*:}"
  if az acr show -n "${acr}" -g "${rg}" -o none 2>/dev/null; then
    sku="$(az acr show -n "${acr}" -g "${rg}" --query sku.name -o tsv 2>/dev/null)"
    used="$(az acr show-usage -n "${acr}" --query "value[?name=='Size'].currentValue" -o tsv 2>/dev/null || echo 0)"
    repos="$(az acr repository list -n "${acr}" -o tsv 2>/dev/null | tr '\n' ' ')"
    log_info "${acr} (rg=${rg}, sku=${sku}, used=$(awk -v b="${used:-0}" 'BEGIN{printf "%.2f", b/1073741824}') GiB)"
    log_info "  repositories: ${repos:-<none>}"
    FOUND+=("${t}")
  else
    log_warn "${acr} not found in ${rg} — already deleted, skipping"
  fi
done

if [[ ${#FOUND[@]} -eq 0 ]]; then
  log_success "Nothing to do — no target registries remain."
  exit 0
fi

if [[ ${DRY_RUN} -eq 1 ]]; then
  log_warn "--dry-run set; no changes made."
  exit 0
fi

log_step "Deleting registries"
for t in "${FOUND[@]}"; do
  acr="${t%%:*}"; rg="${t##*:}"
  log_info "Deleting ${acr} ..."
  if az acr delete -n "${acr}" -g "${rg}" --yes 2>&1; then
    log_success "Deleted ${acr}"
  else
    log_error "Failed to delete ${acr}"
  fi
done

log_step "Verification"
REMAINING="$(az acr list --query '[].name' -o tsv 2>/dev/null | tr '\n' ' ')"
if [[ -z "${REMAINING// /}" ]]; then
  log_success "No container registries remain in the subscription."
else
  log_warn "Registries still present: ${REMAINING}"
fi

log_step "Retained (unchanged; current cost not asserted)"
log_info "Resource groups, CIAM directories, Entra app registrations/SPs,"
log_info "Key Vaults, Postgres, Container Apps, Log Analytics, App Insights,"
log_info "Static Web Apps, managed identities, tfstate storage account."

log_step "Expected outcome"
log_info "Configured registries are absent. Re-query Cost Management and the"
log_info "remaining resource inventory before making any run-rate claim."

log_success "Done. Log: ${LOGFILE}"
exit 0
