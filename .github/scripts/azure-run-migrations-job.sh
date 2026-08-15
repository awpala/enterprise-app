#!/usr/bin/env bash
# Azure adapter: starts the EF Core migrations Container Apps Job and polls to completion.
# Expects Terraform state available under infra/azure and az CLI logged in.
set -euo pipefail

RG=$(terraform -chdir=infra/azure output -raw resource_group_name)
JOB=$(terraform -chdir=infra/azure output -raw migrations_job_name)
echo "Starting migrations job $JOB in $RG"

az containerapp job start --name "$JOB" --resource-group "$RG" --output none

# Poll for the latest execution. It may take a few seconds to appear.
TIMEOUT=600
ELAPSED=0
INTERVAL=10
EXEC=""
while [[ -z "$EXEC" && $ELAPSED -lt 60 ]]; do
  EXEC=$(az containerapp job execution list \
    --name "$JOB" --resource-group "$RG" \
    --query '[0].name' -o tsv 2>/dev/null || true)
  if [[ -z "$EXEC" ]]; then
    sleep 5
    ELAPSED=$((ELAPSED + 5))
  fi
done
if [[ -z "$EXEC" ]]; then
  echo "Could not find a job execution after 60s" >&2
  exit 1
fi
echo "Tailing execution: $EXEC"

ELAPSED=0
while [[ $ELAPSED -lt $TIMEOUT ]]; do
  STATUS=$(az containerapp job execution show \
    --name "$JOB" --resource-group "$RG" \
    --job-execution-name "$EXEC" \
    --query 'properties.status' -o tsv)
  echo "[${ELAPSED}s] status=$STATUS"
  case "$STATUS" in
    Succeeded)
      echo "Migrations succeeded."
      exit 0
      ;;
    Failed|Degraded|Stopped)
      echo "Migrations ended in non-success state: $STATUS" >&2
      exit 1
      ;;
  esac
  sleep $INTERVAL
  ELAPSED=$((ELAPSED + INTERVAL))
done
echo "Timed out after ${TIMEOUT}s waiting for migrations job" >&2
exit 1
