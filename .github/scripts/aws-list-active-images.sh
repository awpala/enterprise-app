#!/usr/bin/env bash
# Lists ECR image references used by current or draining ECS deployments and by
# the one-off migration task definition. Output is tab-separated repository and
# tag (or @digest) pairs, sorted and deduplicated for script consumption.
set -euo pipefail

: "${AWS_REGION:?AWS_REGION is required}"
readonly REPO_ROOT=${GITHUB_WORKSPACE:-$(git rev-parse --show-toplevel)}
readonly TF_ROOT=${TF_ROOT:-"${REPO_ROOT}/infra/aws"}
readonly ECS_DESCRIBE_SERVICES_LIMIT=10

cluster=$(terraform -chdir="$TF_ROOT" output -raw ecs_cluster_name)
migration_task_definition=$(terraform -chdir="$TF_ROOT" output -raw migration_task_definition_arn)
repositories=$(terraform -chdir="$TF_ROOT" output -json ecr_repository_urls)

declare -A known_repositories=()
repository_names=$(jq -r '.[] | sub("^[^/]+/"; "")' <<<"$repositories")
while IFS= read -r repository; do
  [[ -n "$repository" ]] && known_repositories["$repository"]=1
done <<<"$repository_names"

declare -A task_definitions=()
service_list=$(aws ecs list-services \
  --cluster "$cluster" \
  --region "$AWS_REGION" \
  --output json)
service_lines=$(jq -r '.serviceArns[]' <<<"$service_list")
services=()
while IFS= read -r service; do
  [[ -n "$service" ]] && services+=("$service")
done <<<"$service_lines"

for ((offset = 0; offset < ${#services[@]}; offset += ECS_DESCRIBE_SERVICES_LIMIT)); do
  service_batch=("${services[@]:offset:ECS_DESCRIBE_SERVICES_LIMIT}")
  service_data=$(aws ecs describe-services \
    --cluster "$cluster" \
    --services "${service_batch[@]}" \
    --region "$AWS_REGION" \
    --output json)
  if [[ $(jq '.failures | length' <<<"$service_data") -ne 0 ]]; then
    echo "AWS failed to describe one or more ECS services." >&2
    exit 1
  fi
  deployment_task_definitions=$(jq -r '.services[].deployments[].taskDefinition' <<<"$service_data")
  while IFS= read -r task_definition; do
    [[ -n "$task_definition" ]] && task_definitions["$task_definition"]=1
  done <<<"$deployment_task_definitions"
done

if [[ -n "$migration_task_definition" && "$migration_task_definition" != "None" ]]; then
  task_definitions["$migration_task_definition"]=1
fi

for task_definition in "${!task_definitions[@]}"; do
  task_definition_data=$(aws ecs describe-task-definition \
    --task-definition "$task_definition" \
    --region "$AWS_REGION" \
    --output json)
  task_images=$(jq -r '.taskDefinition.containerDefinitions[].image' <<<"$task_definition_data")
  while IFS= read -r image; do
    [[ -n "$image" ]] || continue
    image_path=${image#*/}
    if [[ "$image_path" == *@* ]]; then
      repository=${image_path%@*}
      reference="@${image_path#*@}"
    elif [[ "$image_path" == *:* ]]; then
      repository=${image_path%:*}
      reference=${image_path##*:}
    else
      repository=$image_path
      reference=latest
    fi

    [[ -n "${known_repositories["$repository"]+x}" ]] || continue
    printf '%s\t%s\n' "$repository" "$reference"
  done <<<"$task_images"
done | sort -u
