#!/usr/bin/env bash
set -euo pipefail

TF_ROOT=${TF_ROOT:-infra/aws}
CLUSTER=$(terraform -chdir="$TF_ROOT" output -raw ecs_cluster_name)
TASK=$(terraform -chdir="$TF_ROOT" output -raw migration_task_definition_arn)
SUBNETS=$(terraform -chdir="$TF_ROOT" output -json private_subnet_ids | jq -r 'join(",")')
SECURITY_GROUP=$(terraform -chdir="$TF_ROOT" output -raw ecs_task_security_group_id)

RUN_ARN=$(aws ecs run-task \
  --cluster "$CLUSTER" \
  --task-definition "$TASK" \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$SECURITY_GROUP],assignPublicIp=DISABLED}" \
  --query 'tasks[0].taskArn' \
  --output text)

if [[ -z "$RUN_ARN" || "$RUN_ARN" == "None" ]]; then
  echo "AWS did not return a migration task ARN." >&2
  exit 1
fi

aws ecs wait tasks-stopped --cluster "$CLUSTER" --tasks "$RUN_ARN"
EXIT_CODE=$(aws ecs describe-tasks \
  --cluster "$CLUSTER" \
  --tasks "$RUN_ARN" \
  --query 'tasks[0].containers[?name==`migrations`].exitCode | [0]' \
  --output text)

if [[ "$EXIT_CODE" != "0" ]]; then
  aws ecs describe-tasks --cluster "$CLUSTER" --tasks "$RUN_ARN" --output json
  echo "Migration task failed with exit code $EXIT_CODE." >&2
  exit 1
fi

echo "Migration task completed successfully: $RUN_ARN"
