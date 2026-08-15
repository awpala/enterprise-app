#!/usr/bin/env bash
# Cloud-neutral Terraform entry point. Provider credentials and remote-state
# coordinates stay provider-specific; operation and environment semantics do not.
set -euo pipefail

usage() {
  echo "Usage: $0 <validate|plan|apply|output> <azure|aws> [dev|production]" >&2
}

if [[ $# -lt 2 ]]; then
  usage
  exit 2
fi

OPERATION=$1
CLOUD=$2
ENVIRONMENT=${3:-dev}
REPO_ROOT=$(git rev-parse --show-toplevel)

case "$CLOUD" in
  azure|aws) ;;
  *) echo "Unsupported cloud target: $CLOUD" >&2; usage; exit 2 ;;
esac

case "$ENVIRONMENT" in
  dev|production) ;;
  *) echo "Unsupported environment: $ENVIRONMENT" >&2; usage; exit 2 ;;
esac

TF_ROOT="${REPO_ROOT}/infra/${CLOUD}"
TFVARS_FILE="envs/${ENVIRONMENT}.tfvars"
if [[ "$CLOUD" == "azure" ]]; then
  # Preserve the existing Azure backend keys during the directory refactor.
  STATE_KEY="${ENVIRONMENT}.tfstate"
else
  STATE_KEY="aws/${ENVIRONMENT}.tfstate"
fi

initialize() {
  if [[ "$OPERATION" == "validate" ]]; then
    terraform -chdir="$TF_ROOT" init -backend=false
    return
  fi

  if [[ "$CLOUD" == "azure" ]]; then
    : "${TFSTATE_RESOURCE_GROUP:?Set TFSTATE_RESOURCE_GROUP from the Azure bootstrap output.}"
    : "${TFSTATE_STORAGE_ACCOUNT:?Set TFSTATE_STORAGE_ACCOUNT from the Azure bootstrap output.}"
    : "${TFSTATE_CONTAINER:?Set TFSTATE_CONTAINER from the Azure bootstrap output.}"
    terraform -chdir="$TF_ROOT" init -reconfigure \
      -backend-config="resource_group_name=${TFSTATE_RESOURCE_GROUP}" \
      -backend-config="storage_account_name=${TFSTATE_STORAGE_ACCOUNT}" \
      -backend-config="container_name=${TFSTATE_CONTAINER}" \
      -backend-config="key=${STATE_KEY}"
  else
    : "${AWS_TFSTATE_BUCKET:?Set AWS_TFSTATE_BUCKET from the AWS bootstrap output.}"
    : "${AWS_REGION:?Set AWS_REGION to the deployment region.}"
    terraform -chdir="$TF_ROOT" init -reconfigure \
      -backend-config="bucket=${AWS_TFSTATE_BUCKET}" \
      -backend-config="region=${AWS_REGION}" \
      -backend-config="key=${STATE_KEY}" \
      -backend-config="use_lockfile=true"
  fi
}

case "$OPERATION" in
  validate)
    initialize
    terraform -chdir="$TF_ROOT" validate
    ;;
  plan)
    initialize
    terraform -chdir="$TF_ROOT" plan -var-file="$TFVARS_FILE"
    ;;
  apply)
    initialize
    terraform -chdir="$TF_ROOT" apply -var-file="$TFVARS_FILE"
    ;;
  output)
    initialize
    terraform -chdir="$TF_ROOT" output
    ;;
  *)
    echo "Unsupported operation: $OPERATION" >&2
    usage
    exit 2
    ;;
esac
