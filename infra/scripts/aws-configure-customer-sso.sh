#!/usr/bin/env bash
# Reconciles the customer SSO prerequisites that live outside Terraform state.
# Google credentials are reused from the existing logical GitHub Environment;
# Microsoft personal-account credentials are created through Microsoft Graph
# and written directly to GitHub without printing or persisting the secret.
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: infra/scripts/aws-configure-customer-sso.sh <dev|production> --config <file> [--yes]

  --config FILE  Ignored deployment config based on
                 infra/aws/envs/dev.deploy.env.example.
  --yes          Reconcile without interactive AWS account confirmation.
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

required_variables=(
  AWS_PROFILE
  AWS_REGION
  AWS_NAME_SUFFIX
  GITHUB_OWNER
  GITHUB_REPO
  COGNITO_DOMAIN_PREFIX
)
for variable_name in "${required_variables[@]}"; do
  [[ -n "${!variable_name:-}" ]] || {
    echo "$variable_name must be set in $CONFIG_FILE." >&2
    exit 2
  }
done
for command_name in aws az curl gh jq; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "Required command is unavailable: $command_name" >&2
    exit 2
  }
done

unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_SECURITY_TOKEN
export AWS_PROFILE AWS_REGION
export AWS_DEFAULT_REGION="$AWS_REGION"

GITHUB_REPOSITORY="${GITHUB_OWNER}/${GITHUB_REPO}"
GITHUB_ENVIRONMENT="$ENVIRONMENT"
STATE_BUCKET="ea-tfstate-${AWS_NAME_SUFFIX}"
ROLE_NAME="ea-github-deployer"
MICROSOFT_APP_NAME="ea-aws-${ENVIRONMENT}-outlook-sso"
COGNITO_ORIGIN="https://${COGNITO_DOMAIN_PREFIX}.auth.${AWS_REGION}.amazoncognito.com"
OIDC_CALLBACK="${COGNITO_ORIGIN}/oauth2/idpresponse"

CALLER_IDENTITY=$(aws sts get-caller-identity --output json)
AWS_ACCOUNT_ID=$(jq -r '.Account' <<<"$CALLER_IDENTITY")
CALLER_ARN=$(jq -r '.Arn' <<<"$CALLER_IDENTITY")
if [[ "$CALLER_ARN" == *":root" ]]; then
  echo "Refusing to configure SSO with the AWS account root user." >&2
  exit 1
fi

gh auth status --hostname github.com >/dev/null
gh api "repos/${GITHUB_REPOSITORY}" >/dev/null
az account show --query id --output tsv >/dev/null
az ad signed-in-user show --query id --output tsv >/dev/null
MICROSOFT_AUTHORITY=$(az cloud show --query endpoints.activeDirectory --output tsv)
MICROSOFT_DISCOVERY_URL="${MICROSOFT_AUTHORITY%/}/consumers/v2.0/.well-known/openid-configuration"
MICROSOFT_OIDC_ISSUER=$(curl --fail --silent --show-error "$MICROSOFT_DISCOVERY_URL" | jq -r '.issuer // empty')
[[ "$MICROSOFT_OIDC_ISSUER" == https://* ]] || {
  echo "Microsoft OIDC discovery did not return a valid HTTPS issuer." >&2
  exit 1
}

google_secret_count=$(gh secret list \
  --repo "$GITHUB_REPOSITORY" \
  --env "$GITHUB_ENVIRONMENT" \
  --json name \
  --jq '[.[] | select(.name == "GOOGLE_OIDC_CLIENT_ID" or .name == "GOOGLE_OIDC_CLIENT_SECRET")] | length')
if [[ "$google_secret_count" -ne 2 ]]; then
  echo "The existing Google OAuth credentials are not both present in GitHub Environment $GITHUB_ENVIRONMENT." >&2
  exit 1
fi
microsoft_secret_count=$(gh secret list \
  --repo "$GITHUB_REPOSITORY" \
  --env "$GITHUB_ENVIRONMENT" \
  --json name \
  --jq '[.[] | select(.name == "MICROSOFT_OIDC_CLIENT_ID" or .name == "MICROSOFT_OIDC_CLIENT_SECRET")] | length')

echo "AWS account: $AWS_ACCOUNT_ID"
echo "Environment: $ENVIRONMENT"
echo "GitHub environment: $GITHUB_ENVIRONMENT"
echo "Google credentials: existing protected values found"
echo "Action: reconcile AWS trust/configuration and Microsoft/Outlook SSO"
if [[ "$ASSUME_YES" != "true" ]]; then
  read -r -p "Type the AWS account ID to continue: " confirmation
  [[ "$confirmation" == "$AWS_ACCOUNT_ID" ]] || {
    echo "Account confirmation did not match; no changes made." >&2
    exit 1
  }
fi

application_created=false
application_id=$(az ad app list \
  --display-name "$MICROSOFT_APP_NAME" \
  --query '[0].appId' --output tsv)
if [[ -z "$application_id" ]]; then
  application_id=$(az ad app create \
    --display-name "$MICROSOFT_APP_NAME" \
    --sign-in-audience PersonalMicrosoftAccount \
    --web-redirect-uris "$OIDC_CALLBACK" \
    --query appId --output tsv)
  application_created=true
else
  sign_in_audience=$(az ad app show --id "$application_id" --query signInAudience --output tsv)
  [[ "$sign_in_audience" == "PersonalMicrosoftAccount" ]] || {
    echo "Existing Microsoft application has the wrong sign-in audience; refusing to repurpose it." >&2
    exit 1
  }
  az ad app update --id "$application_id" --web-redirect-uris "$OIDC_CALLBACK" >/dev/null
fi

if [[ "$application_created" == "true" || "$microsoft_secret_count" -ne 2 ]]; then
  credential_end=$(date -u -d '+365 days' '+%Y-%m-%d')
  application_secret=$(az ad app credential reset \
    --id "$application_id" \
    --append \
    --display-name "cognito-${ENVIRONMENT}" \
    --end-date "$credential_end" \
    --query password --output tsv)
  [[ -n "$application_secret" ]] || {
    echo "Microsoft Graph did not return the new application credential." >&2
    exit 1
  }

  gh secret set MICROSOFT_OIDC_CLIENT_ID \
    --env "$GITHUB_ENVIRONMENT" --repo "$GITHUB_REPOSITORY" --body "$application_id"
  gh secret set MICROSOFT_OIDC_CLIENT_SECRET \
    --env "$GITHUB_ENVIRONMENT" --repo "$GITHUB_REPOSITORY" --body "$application_secret"
  unset application_secret
else
  echo "Microsoft credentials: existing protected values found"
fi

deploy_role_arn=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)
trust_policy=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.AssumeRolePolicyDocument' --output json)
trusted_subjects=$(jq -cn \
  --arg repository "$GITHUB_REPOSITORY" \
  '["dev", "production"] | map("repo:\($repository):environment:\(.)")')
updated_trust_policy=$(jq \
  --argjson subjects "$trusted_subjects" \
  '(.Statement[] | select(.Action == "sts:AssumeRoleWithWebIdentity").Condition.StringLike["token.actions.githubusercontent.com:sub"]) = $subjects' \
  <<<"$trust_policy")
aws iam update-assume-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-document "$updated_trust_policy"

gh variable set AWS_REGION \
  --env "$GITHUB_ENVIRONMENT" --repo "$GITHUB_REPOSITORY" --body "$AWS_REGION"
gh variable set AWS_DEPLOY_ROLE_ARN \
  --env "$GITHUB_ENVIRONMENT" --repo "$GITHUB_REPOSITORY" --body "$deploy_role_arn"
gh variable set AWS_TFSTATE_BUCKET \
  --env "$GITHUB_ENVIRONMENT" --repo "$GITHUB_REPOSITORY" --body "$STATE_BUCKET"
gh variable set COGNITO_DOMAIN_PREFIX \
  --env "$GITHUB_ENVIRONMENT" --repo "$GITHUB_REPOSITORY" --body "$COGNITO_DOMAIN_PREFIX"
gh variable set MICROSOFT_OIDC_ISSUER \
  --env "$GITHUB_ENVIRONMENT" --repo "$GITHUB_REPOSITORY" --body "$MICROSOFT_OIDC_ISSUER"

echo "Customer SSO prerequisites reconciled without printing or persisting credentials."
echo "Google and Microsoft/Outlook will be required by the next AWS deployment."
