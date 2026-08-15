#!/usr/bin/env bash

# az-delete-acr.sh — FULL DELETE of Azure cost, by way of the registries.
#
# ---------------------------------------------------------------------------
# THIS IS THE COMPLETE AZURE COST TEARDOWN.
#
# Despite the narrow name, deleting the two Container Registries removes
# 100% of Azure spend on this subscription. That is not an assumption — it
# was established from the Cost Management API before this script was written:
#
#   July 2026 actual:   $5.16 total  — ea-prod-rg / Container Registry $5.16
#                                      every other service line $0.00
#   Aug 1-15 actual:    $2.43 total  — eaprodacreaprd1 $2.42
#                                      eadevacreadev1  $0.01
#                                      Postgres, Log Analytics, Storage $0.00
#
# Every other resource in ea-dev-rg / ea-prod-rg bills $0: Postgres (free-tier
# window), Container Apps (consumption free grant), Log Analytics and App
# Insights (no billable ingestion), Static Web Apps (Free SKU), Key Vaults,
# managed identities, workbooks, the CIAM directories, and the tfstate
# storage account. Deleting them would save nothing and would destroy the
# identities and baseline configs wanted for a future relaunch.
#
# So: "registries only" and "full cost delete" are the same action here.
# After this script runs, expected Azure run-rate is ~$0/mo.
# ---------------------------------------------------------------------------
#
# Why this is NOT az-teardown.sh:
#   az-teardown.sh deletes ACR *repositories* (the images) but leaves the
#   *registry* in place. ACR Basic bills a flat SKU fee (~$5/mo each) that is
#   independent of stored image size, and both registries sit at ~0.28 GiB
#   against a 10 GiB included allowance. Deleting repositories therefore
#   removes the hot-redeploy images while saving $0. Only deleting the
#   registry itself stops the charge. az-teardown.sh also stops Postgres and
#   deletes Container Apps / App Insights, none of which were costing anything.
#
# Two latent costs this does NOT address (nothing bills today, but watch):
#   1. Postgres free-tier window. Both flexible servers (Standard_B1ms, 32 GB)
#      were created 2026-04-12; the 12-month free allowance lapses ~2026-04-12,
#      after which two servers begin billing. Delete them before then if the
#      project is still dormant.
#   2. Cost-data lag. The dev stack (eadevacreadev1, ea-dev-cae, dev Container
#      Apps) was created 2026-08-15 ~10:30 UTC. Cost Management lags 24-48h, so
#      dev's steady-state cost was not yet observable when this was written.
#      Re-check a few days out to confirm dev Container Apps stay at $0.
#
# Resource groups are retained. They contain the CIAM directories
# (eacustomerdev/eacustomerprod), so `az group delete` must NEVER be used here
# — it would destroy the customer identity tenants. Likewise a plain
# `terraform destroy` would drop module.entra_external_id.* (app registrations
# and service principals) and the resource groups themselves.
#
# Terraform: both registries exist in state as module.acr.azurerm_container_registry.this.
# No `terraform state rm` is performed — a later `terraform apply` will refresh,
# observe the registry is gone, and plan to recreate it. That is the desired
# relaunch behavior. Relaunch also requires rebuilding and pushing images,
# since the stored image tags are deleted with the registry.
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

SUBSCRIPTION_ID="5eeebca2-f232-415b-a8cf-6b6688ca5e8f"

# registry:resource-group
TARGETS=(
  "eadevacreadev1:ea-dev-rg"
  "eaprodacreaprd1:ea-prod-rg"
)

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

log_step "Retained (unchanged, \$0 today)"
log_info "Resource groups, CIAM directories, Entra app registrations/SPs,"
log_info "Key Vaults, Postgres, Container Apps, Log Analytics, App Insights,"
log_info "Static Web Apps, managed identities, tfstate storage account."

log_step "Expected outcome"
log_info "Azure run-rate should now be ~\$0/mo — the registries were the only"
log_info "billing line. Watch two latent items: the Postgres free-tier window"
log_info "lapses ~2026-04-12, and dev (created 2026-08-15) is still inside the"
log_info "24-48h cost-reporting lag. Re-check with the Cost Management API."

log_success "Done. Log: ${LOGFILE}"
exit 0
