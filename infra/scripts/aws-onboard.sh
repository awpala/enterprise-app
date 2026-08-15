#!/usr/bin/env bash
# One-time AWS onboarding and optional deployment dispatch. All container builds
# run on GitHub-hosted runners; this script does not require or invoke Docker.
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: infra/scripts/aws-onboard.sh <dev|production> --config <file> [--deploy] [--yes]

  --config FILE  Non-secret KEY=value file based on
                 infra/aws/envs/dev.deploy.env.example.
  --deploy       Dispatch deploy.yml after bootstrap, configuration, and plan.
  --yes          Skip the interactive AWS account confirmation.
EOF
}

if [[ $# -lt 3 ]]; then
  usage
  exit 2
fi

ENVIRONMENT=$1
shift
CONFIG_FILE=""
DEPLOY=false
ASSUME_YES=false

case "$ENVIRONMENT" in
  dev|production) ;;
  *) echo "Environment must be dev or production." >&2; usage; exit 2 ;;
esac

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      [[ $# -ge 2 ]] || { echo "--config requires a file." >&2; exit 2; }
      CONFIG_FILE=$2
      shift 2
      ;;
    --deploy)
      DEPLOY=true
      shift
      ;;
    --yes)
      ASSUME_YES=true
      shift
      ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

[[ -n "$CONFIG_FILE" ]] || { echo "--config is required." >&2; exit 2; }
[[ -f "$CONFIG_FILE" ]] || { echo "Config file not found: $CONFIG_FILE" >&2; exit 2; }

set -a
# shellcheck disable=SC1090
source "$CONFIG_FILE"
set +a

required_variables=(
  AWS_PROFILE
  AWS_REGION
  AWS_NAME_SUFFIX
  GITHUB_OWNER
  GITHUB_REPO
  COGNITO_DOMAIN_PREFIX
  AWS_MONTHLY_BUDGET_USD
  DEPLOY_REF
)
for variable_name in "${required_variables[@]}"; do
  if [[ -z "${!variable_name:-}" ]]; then
    echo "$variable_name must be set in $CONFIG_FILE." >&2
    exit 2
  fi
done
if [[ "$ENVIRONMENT" == "production" && -z "${GITHUB_PRODUCTION_REVIEWER:-}" ]]; then
  echo "GITHUB_PRODUCTION_REVIEWER is required for production." >&2
  exit 2
fi

for command_name in aws terraform jq rg gh git; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "Required command is unavailable: $command_name" >&2
    exit 2
  }
done

if [[ ! "$AWS_NAME_SUFFIX" =~ ^[a-z0-9]{4,10}$ ]]; then
  echo "AWS_NAME_SUFFIX must contain 4-10 lowercase letters or digits." >&2
  exit 2
fi
if [[ ! "$COGNITO_DOMAIN_PREFIX" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; then
  echo "COGNITO_DOMAIN_PREFIX must contain lowercase letters, numbers, and interior hyphens." >&2
  exit 2
fi
if [[ ! "$AWS_MONTHLY_BUDGET_USD" =~ ^[0-9]+([.][0-9]{1,2})?$ ]] \
  || ! awk -v amount="$AWS_MONTHLY_BUDGET_USD" 'BEGIN { exit !(amount > 0) }'; then
  echo "AWS_MONTHLY_BUDGET_USD must be a positive USD amount." >&2
  exit 2
fi
if [[ -n "${AWS_BUDGET_EMAIL:-}" && ! "$AWS_BUDGET_EMAIL" =~ ^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$ ]]; then
  echo "AWS_BUDGET_EMAIL is not a valid email address." >&2
  exit 2
fi

REPO_ROOT=$(git rev-parse --show-toplevel)
BOOTSTRAP_ROOT="${REPO_ROOT}/infra/aws/bootstrap"
AWS_ROOT="${REPO_ROOT}/infra/aws"
TFVARS_FILE="envs/${ENVIRONMENT}.tfvars"
STATE_KEY="aws/${ENVIRONMENT}.tfstate"
STATE_BUCKET="ea-tfstate-${AWS_NAME_SUFFIX}"
GITHUB_REPOSITORY="${GITHUB_OWNER}/${GITHUB_REPO}"
GITHUB_ENVIRONMENT="aws-${ENVIRONMENT}"

# Environment credentials take precedence over AWS_PROFILE. Remove them only
# in this child process so the named short-lived profile is authoritative.
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_SECURITY_TOKEN
export AWS_PROFILE AWS_REGION
export AWS_DEFAULT_REGION="$AWS_REGION"

CALLER_IDENTITY=$(aws sts get-caller-identity --output json)
AWS_ACCOUNT_ID=$(jq -r '.Account' <<<"$CALLER_IDENTITY")
CALLER_ARN=$(jq -r '.Arn' <<<"$CALLER_IDENTITY")
if [[ "$CALLER_ARN" == *":root" ]]; then
  echo "Refusing to onboard or deploy with the AWS account root user." >&2
  echo "Authenticate AWS_PROFILE=$AWS_PROFILE with an IAM Identity Center or assumed role." >&2
  exit 1
fi

TFVARS_REGION=$(awk -F= '
  /^[[:space:]]*aws_region[[:space:]]*=/ {
    value=$2
    gsub(/[[:space:]\"]/, "", value)
    print value
    exit
  }
' "${AWS_ROOT}/${TFVARS_FILE}")
if [[ "$TFVARS_REGION" != "$AWS_REGION" ]]; then
  echo "AWS_REGION=$AWS_REGION does not match ${TFVARS_FILE} ($TFVARS_REGION)." >&2
  exit 2
fi

gh auth status --hostname github.com >/dev/null
gh api "repos/${GITHUB_REPOSITORY}" >/dev/null
REMOTE_DEPLOY_SHA=$(gh api \
  "repos/${GITHUB_REPOSITORY}/commits/${DEPLOY_REF}" \
  --jq '.sha')
LOCAL_DEPLOY_SHA=$(git rev-parse HEAD)
if [[ "$REMOTE_DEPLOY_SHA" != "$LOCAL_DEPLOY_SHA" ]]; then
  echo "DEPLOY_REF=$DEPLOY_REF resolves to $REMOTE_DEPLOY_SHA, but local HEAD is $LOCAL_DEPLOY_SHA." >&2
  echo "Commit and push the exact revision before onboarding or planning." >&2
  exit 2
fi
if [[ -n "$(git status --porcelain --untracked-files=normal)" ]]; then
  echo "The repository has uncommitted changes. Commit the exact deployment revision first." >&2
  exit 2
fi
gh api \
  "repos/${GITHUB_REPOSITORY}/contents/.github/workflows/deploy.yml?ref=${DEPLOY_REF}" \
  >/dev/null

echo "AWS account:       $AWS_ACCOUNT_ID"
echo "AWS caller:        $CALLER_ARN"
echo "AWS region:        $AWS_REGION"
echo "Environment:       $ENVIRONMENT"
echo "Application URL:   AWS-generated CloudFront HTTPS domain"
echo "State bucket:      $STATE_BUCKET"
echo "Monthly budget:    USD $AWS_MONTHLY_BUDGET_USD (${AWS_BUDGET_EMAIL:-no email subscriber})"
echo "GitHub environment:$GITHUB_ENVIRONMENT"
echo "Deployment ref:    $DEPLOY_REF"

if [[ "$ASSUME_YES" != "true" ]]; then
  if [[ ! -t 0 ]]; then
    echo "Non-interactive use requires --yes." >&2
    exit 2
  fi
  read -r -p "Type AWS account ID $AWS_ACCOUNT_ID to continue: " CONFIRMED_ACCOUNT_ID
  if [[ "$CONFIRMED_ACCOUNT_ID" != "$AWS_ACCOUNT_ID" ]]; then
    echo "AWS account confirmation failed." >&2
    exit 1
  fi
fi

ensure_budget() {
  local budget
  local budget_name="ea-${ENVIRONMENT}-monthly"
  local notification
  local notifications
  local subscriber
  local existing_notifications
  local existing_subscribers

  budget=$(jq -n \
    --arg name "$budget_name" \
    --arg amount "$AWS_MONTHLY_BUDGET_USD" \
    '{
      BudgetName: $name,
      BudgetLimit: {Amount: $amount, Unit: "USD"},
      TimeUnit: "MONTHLY",
      BudgetType: "COST"
    }')

  notification='{
    "NotificationType":"ACTUAL",
    "ComparisonOperator":"GREATER_THAN",
    "Threshold":80,
    "ThresholdType":"PERCENTAGE"
  }'
  if aws budgets describe-budget \
    --account-id "$AWS_ACCOUNT_ID" \
    --budget-name "$budget_name" >/dev/null 2>&1; then
    aws budgets update-budget \
      --account-id "$AWS_ACCOUNT_ID" \
      --new-budget "$budget"
    echo "Updated AWS budget $budget_name."
  else
    if [[ -z "${AWS_BUDGET_EMAIL:-}" ]]; then
      aws budgets create-budget \
        --account-id "$AWS_ACCOUNT_ID" \
        --budget "$budget"
      echo "Created AWS budget $budget_name without an email subscriber."
      return
    fi
    subscriber=$(jq -n --arg email "$AWS_BUDGET_EMAIL" \
      '{SubscriptionType: "EMAIL", Address: $email}')
    notifications=$(jq -n \
      --argjson notification "$notification" \
      --argjson subscriber "$subscriber" \
      '[{Notification: $notification, Subscribers: [$subscriber]}]')
    aws budgets create-budget \
      --account-id "$AWS_ACCOUNT_ID" \
      --budget "$budget" \
      --notifications-with-subscribers "$notifications"
    echo "Created AWS budget $budget_name with an 80% actual-spend alert."
    return
  fi

  if [[ -z "${AWS_BUDGET_EMAIL:-}" ]]; then
    echo "Updated AWS budget $budget_name without changing alert subscribers."
    return
  fi

  subscriber=$(jq -n --arg email "$AWS_BUDGET_EMAIL" \
    '{SubscriptionType: "EMAIL", Address: $email}')

  existing_notifications=$(aws budgets describe-notifications-for-budget \
    --account-id "$AWS_ACCOUNT_ID" \
    --budget-name "$budget_name" \
    --output json)
  if ! jq -e '
    any(
      .Notifications[]?;
      .NotificationType == "ACTUAL"
      and .ComparisonOperator == "GREATER_THAN"
      and .Threshold == 80
      and .ThresholdType == "PERCENTAGE"
    )
  ' <<<"$existing_notifications" >/dev/null; then
    aws budgets create-notification \
      --account-id "$AWS_ACCOUNT_ID" \
      --budget-name "$budget_name" \
      --notification "$notification" \
      --subscribers "[$subscriber]"
    echo "Created the 80% actual-spend alert for $budget_name."
    return
  fi

  existing_subscribers=$(aws budgets describe-subscribers-for-notification \
    --account-id "$AWS_ACCOUNT_ID" \
    --budget-name "$budget_name" \
    --notification "$notification" \
    --output json)
  if ! jq -e --arg email "$AWS_BUDGET_EMAIL" \
    'any(.Subscribers[]?; .SubscriptionType == "EMAIL" and .Address == $email)' \
    <<<"$existing_subscribers" >/dev/null; then
    aws budgets create-subscriber \
      --account-id "$AWS_ACCOUNT_ID" \
      --budget-name "$budget_name" \
      --notification "$notification" \
      --subscriber "$subscriber"
    echo "Added $AWS_BUDGET_EMAIL to the $budget_name alert."
  fi
}

ensure_state_bucket() {
  if aws s3api head-bucket --bucket "$STATE_BUCKET" >/dev/null 2>&1; then
    echo "Using existing state bucket $STATE_BUCKET."
  else
    echo "Creating state bucket $STATE_BUCKET."
    if [[ "$AWS_REGION" == "us-east-1" ]]; then
      aws s3api create-bucket --bucket "$STATE_BUCKET" --region "$AWS_REGION" >/dev/null
    else
      aws s3api create-bucket \
        --bucket "$STATE_BUCKET" \
        --region "$AWS_REGION" \
        --create-bucket-configuration "LocationConstraint=${AWS_REGION}" >/dev/null
    fi
  fi

  aws s3api put-bucket-versioning \
    --bucket "$STATE_BUCKET" \
    --versioning-configuration Status=Enabled
  aws s3api put-public-access-block \
    --bucket "$STATE_BUCKET" \
    --public-access-block-configuration \
      BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
  aws s3api put-bucket-encryption \
    --bucket "$STATE_BUCKET" \
    --server-side-encryption-configuration \
      '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
  aws s3api put-bucket-lifecycle-configuration \
    --bucket "$STATE_BUCKET" \
    --lifecycle-configuration \
      '{"Rules":[{"ID":"expire-old-state-versions","Status":"Enabled","Filter":{"Prefix":""},"NoncurrentVersionExpiration":{"NoncurrentDays":90}}]}'
  aws s3api put-bucket-tagging \
    --bucket "$STATE_BUCKET" \
    --tagging \
      'TagSet=[{Key=project,Value=ea},{Key=environment,Value=shared},{Key=managed-by,Value=terraform},{Key=cloud,Value=aws},{Key=purpose,Value=tfstate-and-oidc-bootstrap}]'
}

ensure_service_linked_role() {
  local aws_service_name=$1
  local role_name=$2

  if aws iam get-role --role-name "$role_name" >/dev/null 2>&1; then
    echo "Using existing AWS service-linked role $role_name."
    return
  fi

  aws iam create-service-linked-role \
    --aws-service-name "$aws_service_name" >/dev/null
  echo "Created AWS service-linked role $role_name."
}

ensure_service_linked_roles() {
  ensure_service_linked_role \
    elasticloadbalancing.amazonaws.com \
    AWSServiceRoleForElasticLoadBalancing
  ensure_service_linked_role \
    rds.amazonaws.com \
    AWSServiceRoleForRDS
  ensure_service_linked_role \
    ecs.application-autoscaling.amazonaws.com \
    AWSServiceRoleForApplicationAutoScaling_ECSService
}

terraform_state_has() {
  terraform -chdir="$BOOTSTRAP_ROOT" state list 2>/dev/null | rg -Fxq "$1"
}

terraform_import_if_missing() {
  local address=$1
  local identifier=$2
  if ! terraform_state_has "$address"; then
    echo "Importing $address."
    terraform -chdir="$BOOTSTRAP_ROOT" import "$address" "$identifier"
  fi
}

ensure_bootstrap() {
  local github_oidc_arn
  ensure_state_bucket

  export TF_VAR_aws_region="$AWS_REGION"
  export TF_VAR_name_suffix="$AWS_NAME_SUFFIX"
  export TF_VAR_github_owner="$GITHUB_OWNER"
  export TF_VAR_github_repo="$GITHUB_REPO"

  terraform -chdir="$BOOTSTRAP_ROOT" init -reconfigure \
    -backend-config="bucket=${STATE_BUCKET}" \
    -backend-config="region=${AWS_REGION}" \
    -backend-config="key=aws/bootstrap.tfstate" \
    -backend-config="use_lockfile=true"

  if terraform_state_has 'aws_iam_openid_connect_provider.github[0]'; then
    unset TF_VAR_existing_github_oidc_provider_arn
  else
    github_oidc_arn=$(aws iam list-open-id-connect-providers --output json \
      | jq -r 'first(.OpenIDConnectProviderList[]?.Arn | select(contains("token.actions.githubusercontent.com"))) // empty')
    if [[ -n "$github_oidc_arn" ]]; then
      export TF_VAR_existing_github_oidc_provider_arn="$github_oidc_arn"
      echo "Reusing account-level GitHub OIDC provider $github_oidc_arn."
    else
      unset TF_VAR_existing_github_oidc_provider_arn
    fi
  fi

  terraform_import_if_missing aws_s3_bucket.tfstate "$STATE_BUCKET"
  terraform_import_if_missing aws_s3_bucket_versioning.tfstate "$STATE_BUCKET"
  terraform_import_if_missing aws_s3_bucket_server_side_encryption_configuration.tfstate "$STATE_BUCKET"
  terraform_import_if_missing aws_s3_bucket_public_access_block.tfstate "$STATE_BUCKET"
  terraform_import_if_missing aws_s3_bucket_lifecycle_configuration.tfstate "$STATE_BUCKET"

  if aws iam get-role --role-name ea-github-deployer >/dev/null 2>&1; then
    terraform_import_if_missing aws_iam_role.github_deployer ea-github-deployer
  fi
  if aws iam get-role-policy \
    --role-name ea-github-deployer \
    --policy-name ea-terraform-deployer >/dev/null 2>&1; then
    terraform_import_if_missing \
      aws_iam_role_policy.github_deployer \
      ea-github-deployer:ea-terraform-deployer
  fi

  terraform -chdir="$BOOTSTRAP_ROOT" fmt -check -recursive
  terraform -chdir="$BOOTSTRAP_ROOT" validate
  terraform -chdir="$BOOTSTRAP_ROOT" plan -out=bootstrap.tfplan
  terraform -chdir="$BOOTSTRAP_ROOT" apply bootstrap.tfplan
}

configure_github() {
  local deploy_role_arn
  local environment_payload
  local reviewer_id
  local reviewer_name
  local reviewer_type
  deploy_role_arn=$(terraform -chdir="$BOOTSTRAP_ROOT" output -raw github_deployer_role_arn)

  if [[ "$ENVIRONMENT" == "production" ]]; then
    case "$GITHUB_PRODUCTION_REVIEWER" in
      user:*)
        reviewer_name=${GITHUB_PRODUCTION_REVIEWER#user:}
        reviewer_type=User
        reviewer_id=$(gh api "users/${reviewer_name}" --jq '.id')
        ;;
      team:*)
        reviewer_name=${GITHUB_PRODUCTION_REVIEWER#team:}
        reviewer_type=Team
        reviewer_id=$(gh api \
          "orgs/${GITHUB_OWNER}/teams/${reviewer_name}" \
          --jq '.id')
        ;;
      *)
        echo "GITHUB_PRODUCTION_REVIEWER must use user:<login> or team:<slug>." >&2
        exit 2
        ;;
    esac
    environment_payload=$(jq -n \
      --arg type "$reviewer_type" \
      --argjson id "$reviewer_id" \
      '{
        wait_timer: 0,
        prevent_self_review: true,
        reviewers: [{type: $type, id: $id}]
      }')
    gh api --method PUT \
      "repos/${GITHUB_REPOSITORY}/environments/${GITHUB_ENVIRONMENT}" \
      --input - <<<"$environment_payload" >/dev/null
  elif ! gh api \
    "repos/${GITHUB_REPOSITORY}/environments/${GITHUB_ENVIRONMENT}" \
    >/dev/null 2>&1; then
    gh api --method PUT \
      "repos/${GITHUB_REPOSITORY}/environments/${GITHUB_ENVIRONMENT}" >/dev/null
  fi
  gh variable set AWS_REGION \
    --env "$GITHUB_ENVIRONMENT" --repo "$GITHUB_REPOSITORY" --body "$AWS_REGION"
  gh variable set AWS_DEPLOY_ROLE_ARN \
    --env "$GITHUB_ENVIRONMENT" --repo "$GITHUB_REPOSITORY" --body "$deploy_role_arn"
  gh variable set AWS_TFSTATE_BUCKET \
    --env "$GITHUB_ENVIRONMENT" --repo "$GITHUB_REPOSITORY" --body "$STATE_BUCKET"
  gh variable set COGNITO_DOMAIN_PREFIX \
    --env "$GITHUB_ENVIRONMENT" --repo "$GITHUB_REPOSITORY" --body "$COGNITO_DOMAIN_PREFIX"
}

plan_application() {
  export AWS_TFSTATE_BUCKET="$STATE_BUCKET"
  export TF_VAR_cognito_domain_prefix="$COGNITO_DOMAIN_PREFIX"

  terraform -chdir="$AWS_ROOT" init -reconfigure \
    -backend-config="bucket=${STATE_BUCKET}" \
    -backend-config="region=${AWS_REGION}" \
    -backend-config="key=${STATE_KEY}" \
    -backend-config="use_lockfile=true"
  terraform -chdir="$AWS_ROOT" fmt -check -recursive
  terraform -chdir="$AWS_ROOT" validate
  terraform -chdir="$AWS_ROOT" plan \
    -var-file="$TFVARS_FILE" \
    -out="aws-${ENVIRONMENT}.tfplan"
  echo "Saved application plan: infra/aws/aws-${ENVIRONMENT}.tfplan"
}

dispatch_deployment() {
  gh workflow view deploy.yml --repo "$GITHUB_REPOSITORY" >/dev/null
  gh workflow run deploy.yml \
    --repo "$GITHUB_REPOSITORY" \
    --ref "$DEPLOY_REF" \
    -f target=aws \
    -f environment="$ENVIRONMENT"
  echo "Deployment dispatched. Monitor with:"
  echo "gh run list --repo $GITHUB_REPOSITORY --workflow deploy.yml --limit 1"
}

ensure_budget
ensure_service_linked_roles
ensure_bootstrap
configure_github
plan_application

if [[ "$DEPLOY" == "true" ]]; then
  dispatch_deployment
else
  echo "Onboarding and planning are complete. Re-run with --deploy to dispatch GitHub Actions."
fi
