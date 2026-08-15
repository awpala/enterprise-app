#!/usr/bin/env bash
# Provisions the sole IAM Identity Center administrator as the native Cognito
# user for the selected application environment. No email address or password
# is written to the repository or printed by this script.
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: infra/scripts/aws-provision-cognito-admin.sh <dev|production> --config <file> [--yes]

  --config FILE  Ignored deployment config based on
                 infra/aws/envs/dev.deploy.env.example.
  --yes          Send the Cognito invitation without an interactive account check.
EOF
}

if [[ $# -lt 3 ]]; then
  usage
  exit 2
fi

ENVIRONMENT=$1
shift
CONFIG_FILE=""
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

for variable_name in AWS_PROFILE AWS_REGION; do
  if [[ -z "${!variable_name:-}" ]]; then
    echo "$variable_name must be set in $CONFIG_FILE." >&2
    exit 2
  fi
done
for command_name in aws jq; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "Required command is unavailable: $command_name" >&2
    exit 2
  }
done

unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_SECURITY_TOKEN
export AWS_PROFILE AWS_REGION
export AWS_DEFAULT_REGION="$AWS_REGION"

CALLER_IDENTITY=$(aws sts get-caller-identity --output json)
AWS_ACCOUNT_ID=$(jq -r '.Account' <<<"$CALLER_IDENTITY")
CALLER_ARN=$(jq -r '.Arn' <<<"$CALLER_IDENTITY")
if [[ "$CALLER_ARN" == *":root" ]]; then
  echo "Refusing to provision an application user with the AWS account root user." >&2
  exit 1
fi

IDENTITY_STORE_ID=$(aws sso-admin list-instances --query 'Instances[0].IdentityStoreId' --output text)
[[ "$IDENTITY_STORE_ID" != "None" ]] || {
  echo "IAM Identity Center is not configured." >&2
  exit 1
}

ADMIN_USER=$(aws identitystore list-users \
  --identity-store-id "$IDENTITY_STORE_ID" \
  --filters AttributePath=UserName,AttributeValue=admin \
  --query 'Users[0]' --output json)
[[ "$ADMIN_USER" != "null" ]] || {
  echo "IAM Identity Center user admin was not found." >&2
  exit 1
}

ADMIN_EMAIL=$(jq -r '((.Emails // []) | map(select(.Primary == true))[0].Value) // (.Emails[0].Value // empty)' <<<"$ADMIN_USER")
ADMIN_NAME=$(jq -r '.DisplayName // .UserName' <<<"$ADMIN_USER")
[[ "$ADMIN_EMAIL" =~ ^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$ ]] || {
  echo "IAM Identity Center user admin has no valid primary email." >&2
  exit 1
}

POOL_NAME="ea-${ENVIRONMENT}-users"
USER_POOL_ID=$(aws cognito-idp list-user-pools --max-results 60 \
  --query "UserPools[?Name=='${POOL_NAME}'].Id | [0]" --output text)
[[ "$USER_POOL_ID" != "None" ]] || {
  echo "Cognito user pool $POOL_NAME was not found. Deploy the environment first." >&2
  exit 1
}

CLIENT_ID=$(aws cognito-idp list-user-pool-clients --user-pool-id "$USER_POOL_ID" \
  --query "UserPoolClients[?ClientName=='ea-${ENVIRONMENT}-ui'].ClientId | [0]" --output text)
[[ "$CLIENT_ID" != "None" ]] || {
  echo "Cognito UI client was not found." >&2
  exit 1
}
aws cognito-idp describe-managed-login-branding-by-client \
  --user-pool-id "$USER_POOL_ID" --client-id "$CLIENT_ID" >/dev/null 2>&1 || {
  echo "Cognito managed login is not ready. Deploy the branding resource first." >&2
  exit 1
}

EXISTING_USER_COUNT=$(aws cognito-idp list-users --user-pool-id "$USER_POOL_ID" \
  --filter "email = \"${ADMIN_EMAIL}\"" --query 'length(Users)' --output text)
if [[ "$EXISTING_USER_COUNT" -gt 1 ]]; then
  echo "More than one Cognito user matches the Identity Center administrator." >&2
  exit 1
fi
if [[ "$EXISTING_USER_COUNT" -eq 1 ]]; then
  USER_STATUS=$(aws cognito-idp list-users --user-pool-id "$USER_POOL_ID" \
    --filter "email = \"${ADMIN_EMAIL}\"" --query 'Users[0].UserStatus' --output text)
  echo "Cognito administrator already exists with status $USER_STATUS. No invitation sent."
  exit 0
fi

echo "AWS account: $AWS_ACCOUNT_ID"
echo "Environment: $ENVIRONMENT"
echo "Identity Center user: admin (primary email redacted)"
echo "Action: send one Cognito temporary-password invitation"
if [[ "$ASSUME_YES" != "true" ]]; then
  read -r -p "Type the AWS account ID to send the invitation: " confirmation
  [[ "$confirmation" == "$AWS_ACCOUNT_ID" ]] || {
    echo "Account confirmation did not match; no invitation sent." >&2
    exit 1
  }
fi

aws cognito-idp admin-create-user \
  --user-pool-id "$USER_POOL_ID" \
  --username "$ADMIN_EMAIL" \
  --user-attributes \
    "Name=email,Value=${ADMIN_EMAIL}" \
    'Name=email_verified,Value=true' \
    "Name=name,Value=${ADMIN_NAME}" \
  --desired-delivery-mediums EMAIL >/dev/null

echo "Cognito invitation sent to the Identity Center administrator's primary email."
echo "Use the temporary password at managed login and set a permanent password when prompted."
