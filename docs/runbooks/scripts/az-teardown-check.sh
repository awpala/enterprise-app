#!/usr/bin/env bash

# Check high-cost resources for both environments (non-destructive)
# Usage: ./az-teardown-check.sh
# Exits 0 if no high-cost resources are detected, 2 if any remain.

set -euo pipefail

LOG_DIR="/workspace/__logs"
mkdir -p "${LOG_DIR}"
LOGFILE="${LOG_DIR}/az-teardown-check__$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "${LOGFILE}") 2>&1

echo "Logging to: ${LOGFILE}"

logi(){ echo "[INFO] $*"; }
logw(){ echo "[WARN] $*"; }
loge(){ echo "[ALERT] $*"; }

: "${AZURE_DEV_RESOURCE_GROUP:?Set AZURE_DEV_RESOURCE_GROUP from the approved operator configuration.}"
: "${AZURE_PRODUCTION_RESOURCE_GROUP:?Set AZURE_PRODUCTION_RESOURCE_GROUP from the approved operator configuration.}"
: "${AZURE_DEV_KEY_VAULT:?Set AZURE_DEV_KEY_VAULT from the approved operator configuration.}"
: "${AZURE_PRODUCTION_KEY_VAULT:?Set AZURE_PRODUCTION_KEY_VAULT from the approved operator configuration.}"
: "${TFSTATE_RESOURCE_GROUP:?Set TFSTATE_RESOURCE_GROUP from the Azure bootstrap output.}"
: "${TFSTATE_STORAGE_ACCOUNT:?Set TFSTATE_STORAGE_ACCOUNT from the Azure bootstrap output.}"
: "${TFSTATE_CONTAINER:?Set TFSTATE_CONTAINER from the Azure bootstrap output.}"

declare -A RG=( [dev]="$AZURE_DEV_RESOURCE_GROUP" [prod]="$AZURE_PRODUCTION_RESOURCE_GROUP" )
ENVS=(dev prod)

# Key Vault names per environment (check soft-delete)
declare -A KV=( [dev]="$AZURE_DEV_KEY_VAULT" [prod]="$AZURE_PRODUCTION_KEY_VAULT" )

overall_status=0

# Bootstrap / TFSTATE backend details (required for redeploy)
BOOTSTRAP_RG="$TFSTATE_RESOURCE_GROUP"
BOOTSTRAP_SA="$TFSTATE_STORAGE_ACCOUNT"
BOOTSTRAP_CONTAINER="$TFSTATE_CONTAINER"
TFSTATE_KEYS=(dev.tfstate production.tfstate)

for e in "${ENVS[@]}"; do
  rg=${RG[$e]}
  echo
  echo "==> Check: ${e} (resource group: ${rg})"

  # Postgres: detect any server in Ready state (running)
  logi "Checking PostgreSQL flexible servers"
  pg_list=$(az postgres flexible-server list --resource-group "${rg}" --query "[].{name:name,state:state}" -o tsv 2>/dev/null || true)
  if [[ -z "${pg_list}" ]]; then
    logi "No Postgres servers found in ${rg}"
  else
    echo "Postgres servers (name | state):"
    echo "${pg_list}" | sed 's/\t/ | /g'
    ready_count=0
    while IFS=$'\t' read -r name state; do
      if [[ "${state}" == "Ready" ]]; then
        ((ready_count++))
      fi
    done <<< "${pg_list}"
    if [[ ${ready_count} -gt 0 ]]; then
      loge "${ready_count} Postgres server(s) in Ready state in ${rg} — cost risk"
      overall_status=2
    else
      logi "No running Postgres servers in ${rg}"
    fi
  fi

  # Container Apps
  logi "Checking Container Apps"
  ca_count=$(az containerapp list --resource-group "${rg}" --query "length(@)" -o tsv 2>/dev/null || echo 0)
  if [[ "${ca_count}" -gt 0 ]]; then
    loge "${ca_count} Container App(s) present in ${rg} — cost risk"
    az containerapp list --resource-group "${rg}" --query "[].{name:name, status:properties.runningStatus}" -o table || true
    overall_status=2
  else
    logi "No Container Apps in ${rg}"
  fi

  # Application Insights
  logi "Checking Application Insights"
  ai_count=$(az monitor app-insights component list --resource-group "${rg}" --query "length(@)" -o tsv 2>/dev/null || echo 0)
  if [[ "${ai_count}" -gt 0 ]]; then
    loge "${ai_count} Application Insights component(s) present in ${rg} — cost/ingest risk"
    az monitor app-insights component list --resource-group "${rg}" -o table || true
    overall_status=2
  else
    logi "No Application Insights components in ${rg}"
  fi

  # ACR repositories
  logi "Checking ACR registries and repositories"
  regs=$(az acr list --resource-group "${rg}" --query "[].name" -o tsv 2>/dev/null || true)
  if [[ -z "${regs}" ]]; then
    logi "No ACR registries in ${rg}"
  else
    echo "ACR registries found:"
    echo "${regs}" | while IFS= read -r acr; do
      echo "- ${acr}"
      repo_count=$(az acr repository list -n "${acr}" -o tsv 2>/dev/null | wc -l || echo 0)
      loge "  registry ${acr} remains (repositories: ${repo_count}) — review its current SKU cost"
      overall_status=2
    done
  fi

done

echo
logi "Checking bootstrap backend (tfstate storage)"
sa_exists=$(az storage account show -g "${BOOTSTRAP_RG}" -n "${BOOTSTRAP_SA}" --query "name" -o tsv 2>/dev/null || true)
if [[ -z "${sa_exists}" ]]; then
  loge "Bootstrap storage account ${BOOTSTRAP_SA} not found in ${BOOTSTRAP_RG} — redeploy at risk"
  overall_status=2
else
  logi "Found storage account ${BOOTSTRAP_SA} in ${BOOTSTRAP_RG}"
  container_exists=$(az storage container exists -n "${BOOTSTRAP_CONTAINER}" --account-name "${BOOTSTRAP_SA}" --query "exists" -o tsv 2>/dev/null || echo false)
  if [[ "${container_exists}" != "true" ]]; then
    loge "TFSTATE container '${BOOTSTRAP_CONTAINER}' missing in ${BOOTSTRAP_SA}"
    overall_status=2
  else
    logi "TFSTATE container '${BOOTSTRAP_CONTAINER}' exists"
    for key in "${TFSTATE_KEYS[@]}"; do
      blob_exists=$(az storage blob exists --account-name "${BOOTSTRAP_SA}" -c "${BOOTSTRAP_CONTAINER}" -n "${key}" --query "exists" -o tsv 2>/dev/null || echo false)
      if [[ "${blob_exists}" == "true" ]]; then
        logi "Found tfstate blob: ${key}"
      else
        logw "Missing tfstate blob: ${key} — may indicate state was deleted or moved"
        overall_status=2
      fi
    done
  fi
fi

echo
logi "Checking Key Vault soft-delete status"
for e in "${ENVS[@]}"; do
  kv_name=${KV[$e]}
  if [[ -z "${kv_name}" ]]; then
    continue
  fi
  logi "Checking Key Vault (env=${e}): ${kv_name}"
  kv_deleted=$(az keyvault list-deleted --query "[?name=='${kv_name}'] | [0].name" -o tsv 2>/dev/null || true)
  if [[ -n "${kv_deleted}" ]]; then
    loge "Key Vault '${kv_name}' is soft-deleted and blocks name reuse (env=${e})"
    overall_status=2
  else
    logi "Key Vault name '${kv_name}' is available (not soft-deleted) or owned currently"
  fi
done

echo
logi "Checking current principal and role assignments (RBAC)"
# Get signed-in principal identifier (UPN for user, clientId for SP)
acct_name=$(az account show --query user.name -o tsv 2>/dev/null || true)
acct_type=$(az account show --query user.type -o tsv 2>/dev/null || true)
logi "Signed-in account: ${acct_name} (${acct_type})"
if [[ -z "${acct_name}" ]]; then
  logw "Cannot determine signed-in principal identifier; skipping RBAC checks"
else
  # Query role assignments using --assignee (accepts UPN/clientId/objectId)
  role_table=$(az role assignment list --assignee "${acct_name}" --query "[].{role:roleDefinitionName,scope:scope}" -o table 2>/dev/null || true)
  if [[ -z "${role_table}" || "${role_table}" == "[]" ]]; then
    logw "No role assignments returned for principal ${acct_name} (may lack permission to read assignments or none exist)"
  else
    echo "Role assignments for principal:";
    echo "${role_table}"
    has_contrib=$(az role assignment list --assignee "${acct_name}" --query "[?roleDefinitionName=='Owner' || roleDefinitionName=='Contributor'] | length(@)" -o tsv 2>/dev/null || echo 0)
    if [[ "${has_contrib}" -eq 0 ]]; then
      logw "Signed-in principal does not have Owner/Contributor role assignments — may not be able to create required resources (informational only)"
    else
      logi "Signed-in principal has Owner/Contributor roles (sufficient for deploy operations)"
    fi
  fi
fi

echo
logi "Checking GitHub CLI (GH) for secrets / OIDC checks"
if command -v gh >/dev/null 2>&1; then
  gh auth status || logw "gh auth status failed or not authenticated"
  # Attempt to find repo from git remote
  git_url=$(git config --get remote.origin.url || true)
  if [[ -n "${git_url}" ]]; then
    logi "Detected git remote: ${git_url} — use 'gh' manually to inspect repo secrets if needed"
  else
    logw "No git remote detected; cannot inspect GitHub repo secrets automatically"
  fi
else
  logw "GitHub CLI 'gh' not installed — cannot check repo secrets or OIDC settings automatically"
fi

echo
logi "Extra: scanning for other soft-deleted Key Vaults in subscription (informational)"
kv_list=$(az keyvault list-deleted --query "[].{name:name,scheduled:properties.scheduledPurgeDate}" -o table 2>/dev/null || true)
if [[ -n "${kv_list}" ]]; then
  echo "Soft-deleted Key Vaults in subscription:";
  echo "${kv_list}"
fi

echo
if [[ ${overall_status} -eq 0 ]]; then
  logi "No targeted runtime resources detected and bootstrap state is intact."
  exit 0
else
  loge "One or more checks failed. Review above output and fix before redeploy."
  exit 2
fi
