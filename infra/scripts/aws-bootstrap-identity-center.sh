#!/usr/bin/env bash
# Bootstrap the sole human administrator into a new AWS account. This script is
# intentionally separate from aws-onboard.sh because it starts with root access
# and ends by configuring the non-root IAM Identity Center profile used there.
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: infra/scripts/aws-bootstrap-identity-center.sh [options]

  --source-profile NAME  Existing root-authenticated AWS CLI profile (default: default)
  --profile NAME         IAM Identity Center CLI profile to configure (default: ea-bootstrap)
  --region REGION        IAM Identity Center and deployment region (default: us-east-1)
  --user NAME            Sole administrator user name (default: admin)
  --group NAME           Sole administrator group name (default: admin)
  --permission-set NAME  Bootstrap permission set (default: EAAdministratorBootstrap)
  --yes                  Skip the AWS account ID confirmation
EOF
}

SOURCE_PROFILE=default
TARGET_PROFILE=ea-bootstrap
AWS_REGION=us-east-1
ADMIN_USER=admin
ADMIN_GROUP=admin
PERMISSION_SET_NAME=EAAdministratorBootstrap
ASSUME_YES=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source-profile) SOURCE_PROFILE=${2:?}; shift 2 ;;
    --profile) TARGET_PROFILE=${2:?}; shift 2 ;;
    --region) AWS_REGION=${2:?}; shift 2 ;;
    --user) ADMIN_USER=${2:?}; shift 2 ;;
    --group) ADMIN_GROUP=${2:?}; shift 2 ;;
    --permission-set) PERMISSION_SET_NAME=${2:?}; shift 2 ;;
    --yes) ASSUME_YES=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

for command_name in aws jq; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "Required command is unavailable: $command_name" >&2
    exit 2
  }
done

# A named profile must win over any exported long-lived credentials.
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_SECURITY_TOKEN
AWS=(aws --profile "$SOURCE_PROFILE" --region "$AWS_REGION")

caller_identity=$("${AWS[@]}" sts get-caller-identity --output json)
account_id=$(jq -r '.Account' <<<"$caller_identity")
caller_arn=$(jq -r '.Arn' <<<"$caller_identity")
if [[ "$caller_arn" != *":root" ]]; then
  echo "This one-time bootstrap requires the currently authenticated account root." >&2
  echo "Resolved caller: $caller_arn" >&2
  exit 1
fi

instances=$("${AWS[@]}" sso-admin list-instances --output json)
if [[ $(jq '.Instances | length' <<<"$instances") -ne 1 ]]; then
  echo "Expected exactly one IAM Identity Center instance in account $account_id." >&2
  exit 1
fi
instance_arn=$(jq -r '.Instances[0].InstanceArn' <<<"$instances")
identity_store_id=$(jq -r '.Instances[0].IdentityStoreId' <<<"$instances")
instance_status=$(jq -r '.Instances[0].Status' <<<"$instances")
if [[ "$instance_status" != "ACTIVE" ]]; then
  echo "IAM Identity Center is not active (status: $instance_status)." >&2
  exit 1
fi

groups=$("${AWS[@]}" identitystore list-groups \
  --identity-store-id "$identity_store_id" \
  --filters "AttributePath=DisplayName,AttributeValue=${ADMIN_GROUP}" \
  --output json)
users=$("${AWS[@]}" identitystore list-users \
  --identity-store-id "$identity_store_id" \
  --filters "AttributePath=UserName,AttributeValue=${ADMIN_USER}" \
  --output json)
if [[ $(jq '.Groups | length' <<<"$groups") -ne 1 ]]; then
  echo "Expected exactly one IAM Identity Center group named $ADMIN_GROUP." >&2
  exit 1
fi
if [[ $(jq '.Users | length' <<<"$users") -ne 1 ]]; then
  echo "Expected exactly one IAM Identity Center user named $ADMIN_USER." >&2
  exit 1
fi
group_id=$(jq -r '.Groups[0].GroupId' <<<"$groups")
user_id=$(jq -r '.Users[0].UserId' <<<"$users")

memberships=$("${AWS[@]}" identitystore list-group-memberships \
  --identity-store-id "$identity_store_id" \
  --group-id "$group_id" \
  --output json)
if ! jq -e --arg user_id "$user_id" \
  '.GroupMemberships | any(.MemberId.UserId == $user_id)' \
  <<<"$memberships" >/dev/null; then
  echo "User $ADMIN_USER is not a member of group $ADMIN_GROUP." >&2
  exit 1
fi

echo "AWS account:       $account_id"
echo "Root caller:       $caller_arn"
echo "Administrator:     user $ADMIN_USER through group $ADMIN_GROUP"
echo "Permission set:    $PERMISSION_SET_NAME"
echo "Target CLI profile:$TARGET_PROFILE"
if [[ "$ASSUME_YES" != "true" ]]; then
  if [[ ! -t 0 ]]; then
    echo "Non-interactive use requires --yes." >&2
    exit 2
  fi
  read -r -p "Type AWS account ID $account_id to continue: " confirmed_account_id
  [[ "$confirmed_account_id" == "$account_id" ]] || {
    echo "AWS account confirmation failed." >&2
    exit 1
  }
fi

permission_set_arn=""
while IFS= read -r candidate_arn; do
  [[ -n "$candidate_arn" ]] || continue
  candidate_name=$("${AWS[@]}" sso-admin describe-permission-set \
    --instance-arn "$instance_arn" \
    --permission-set-arn "$candidate_arn" \
    --query 'PermissionSet.Name' \
    --output text)
  if [[ "$candidate_name" == "$PERMISSION_SET_NAME" ]]; then
    permission_set_arn=$candidate_arn
    break
  fi
done < <("${AWS[@]}" sso-admin list-permission-sets \
  --instance-arn "$instance_arn" \
  --query 'PermissionSets[]' \
  --output text | tr '\t' '\n')

if [[ -z "$permission_set_arn" ]]; then
  echo "Creating permission set $PERMISSION_SET_NAME."
  permission_set_arn=$("${AWS[@]}" sso-admin create-permission-set \
    --instance-arn "$instance_arn" \
    --name "$PERMISSION_SET_NAME" \
    --description "Temporary administrator access for the sole enterprise-app operator" \
    --session-duration PT4H \
    --tags Key=project,Value=ea Key=managed-by,Value=aws-bootstrap-identity-center \
    --query 'PermissionSet.PermissionSetArn' \
    --output text)
else
  echo "Using existing permission set $PERMISSION_SET_NAME."
  "${AWS[@]}" sso-admin update-permission-set \
    --instance-arn "$instance_arn" \
    --permission-set-arn "$permission_set_arn" \
    --description "Temporary administrator access for the sole enterprise-app operator" \
    --session-duration PT4H
fi

administrator_policy_arn=arn:aws:iam::aws:policy/AdministratorAccess
managed_policies=$("${AWS[@]}" sso-admin list-managed-policies-in-permission-set \
  --instance-arn "$instance_arn" \
  --permission-set-arn "$permission_set_arn" \
  --output json)
if ! jq -e --arg arn "$administrator_policy_arn" \
  '.AttachedManagedPolicies | any(.Arn == $arn)' \
  <<<"$managed_policies" >/dev/null; then
  echo "Attaching AdministratorAccess to $PERMISSION_SET_NAME."
  "${AWS[@]}" sso-admin attach-managed-policy-to-permission-set \
    --instance-arn "$instance_arn" \
    --permission-set-arn "$permission_set_arn" \
    --managed-policy-arn "$administrator_policy_arn"
fi

assignments=$("${AWS[@]}" sso-admin list-account-assignments \
  --instance-arn "$instance_arn" \
  --account-id "$account_id" \
  --permission-set-arn "$permission_set_arn" \
  --output json)
if jq -e --arg group_id "$group_id" \
  '.AccountAssignments | any(.PrincipalType == "GROUP" and .PrincipalId == $group_id)' \
  <<<"$assignments" >/dev/null; then
  echo "Group $ADMIN_GROUP is already assigned to account $account_id."
  provision_request=$("${AWS[@]}" sso-admin provision-permission-set \
    --instance-arn "$instance_arn" \
    --permission-set-arn "$permission_set_arn" \
    --target-type AWS_ACCOUNT \
    --target-id "$account_id" \
    --query 'PermissionSetProvisioningStatus.RequestId' \
    --output text)
  for _ in $(seq 1 60); do
    provision_status=$("${AWS[@]}" sso-admin describe-permission-set-provisioning-status \
      --instance-arn "$instance_arn" \
      --provision-permission-set-request-id "$provision_request" \
      --query 'PermissionSetProvisioningStatus.Status' \
      --output text)
    [[ "$provision_status" == "SUCCEEDED" ]] && break
    [[ "$provision_status" == "FAILED" ]] && {
      echo "Permission set provisioning failed." >&2
      exit 1
    }
    sleep 2
  done
  [[ "$provision_status" == "SUCCEEDED" ]] || {
    echo "Timed out provisioning the permission set." >&2
    exit 1
  }
else
  echo "Assigning group $ADMIN_GROUP to account $account_id."
  assignment_request=$("${AWS[@]}" sso-admin create-account-assignment \
    --instance-arn "$instance_arn" \
    --target-id "$account_id" \
    --target-type AWS_ACCOUNT \
    --permission-set-arn "$permission_set_arn" \
    --principal-type GROUP \
    --principal-id "$group_id" \
    --query 'AccountAssignmentCreationStatus.RequestId' \
    --output text)
  for _ in $(seq 1 60); do
    assignment_status=$("${AWS[@]}" sso-admin describe-account-assignment-creation-status \
      --instance-arn "$instance_arn" \
      --account-assignment-creation-request-id "$assignment_request" \
      --query 'AccountAssignmentCreationStatus.Status' \
      --output text)
    [[ "$assignment_status" == "SUCCEEDED" ]] && break
    [[ "$assignment_status" == "FAILED" ]] && {
      echo "Account assignment failed." >&2
      exit 1
    }
    sleep 2
  done
  [[ "$assignment_status" == "SUCCEEDED" ]] || {
    echo "Timed out creating the account assignment." >&2
    exit 1
  }
fi

# Use the AWS CLI's supported legacy SSO profile keys so this step remains
# non-interactive. `aws sso login` supplies the unavoidable browser sign-in.
sso_start_url="https://${identity_store_id}.awsapps.com/start"
aws configure set sso_start_url "$sso_start_url" --profile "$TARGET_PROFILE"
aws configure set sso_region "$AWS_REGION" --profile "$TARGET_PROFILE"
aws configure set sso_account_id "$account_id" --profile "$TARGET_PROFILE"
aws configure set sso_role_name "$PERMISSION_SET_NAME" --profile "$TARGET_PROFILE"
aws configure set region "$AWS_REGION" --profile "$TARGET_PROFILE"
aws configure set output json --profile "$TARGET_PROFILE"

echo
echo "Identity bootstrap is complete. Root credentials are no longer needed."
echo "Complete the browser sign-in with:"
echo "  aws sso login --profile $TARGET_PROFILE"
echo "Then verify the non-root session with:"
echo "  aws sts get-caller-identity --profile $TARGET_PROFILE"
