# AWS deployment runbook

This is the operational path for onboarding and deploying the application to AWS. The detailed [AWS deployment workbook](../workbooks/aws-deployment-workbook.md) is an evidence and production-readiness checklist, not a command sequence.

The current operating profile is an on-demand portfolio demo. Application and identity data is disposable; rebuild and reseed after loss. Backup, restore, high-availability, and retention gates in the historical workbook are optional hardening references, not prerequisites for these demos. Verify the selected account/environment and keep changes scoped to this application.

## One-time interactive prerequisites

Complete only the identity steps that require a browser:

1. Sign in as the AWS account root user, secure root with multiple MFA methods, and enable IAM Identity Center. Create the sole human user `admin`, the group `admin`, and add that user to that group.
2. Run the idempotent identity bootstrap once. It creates the `EAAdministratorBootstrap` permission set, assigns the existing `admin` group to this account, and configures the local `ea-bootstrap` profile:

   ```bash
   infra/scripts/aws-bootstrap-identity-center.sh
   ```

3. Complete the browser sign-in and verify that the CLI is no longer root:

   ```bash
   aws sso login --profile ea-bootstrap
   aws sts get-caller-identity --profile ea-bootstrap
   ```

4. Authenticate the GitHub CLI with permission to manage repository environments and Actions:

   ```bash
   gh auth login
   ```

5. Verify the Microsoft CLI session used by the scripted Outlook application
   registration:

   ```bash
   az account show
   az ad signed-in-user show
   ```

`aws-onboard.sh` rejects an AWS root identity. Do not create or export AWS access keys. Docker is intentionally absent from `ea-dev-env`; GitHub-hosted runners build and push all images.

## Configure once

Create the ignored, non-secret deployment config:

```bash
cd /workspace
cp infra/aws/envs/dev.deploy.env.example infra/aws/envs/dev.deploy.env
```

Edit `infra/aws/envs/dev.deploy.env`:

```dotenv
AWS_PROFILE=ea-bootstrap
AWS_REGION=us-east-1
AWS_NAME_SUFFIX=replace1
GITHUB_OWNER=replace-with-repository-owner
GITHUB_REPO=replace-with-repository-name
COGNITO_DOMAIN_PREFIX=replace-with-globally-unique-prefix
AWS_MONTHLY_BUDGET_USD=100
AWS_BUDGET_EMAIL=
DEPLOY_REF=main
GITHUB_PRODUCTION_REVIEWER=
```

`AWS_NAME_SUFFIX` must be 4-10 lowercase letters or numbers and makes the S3 state bucket globally unique. `AWS_BUDGET_EMAIL` is optional; when empty, the budget is created without an email subscriber. `DEPLOY_REF` must contain the committed AWS workflow and application revision to deploy. The script requires a clean worktree and verifies that local `HEAD` exactly matches that remote ref, ensuring the reviewed plan and GitHub build use one commit.

The selected region must match `aws_region` in `infra/aws/envs/dev.tfvars`. CloudFront supplies the public HTTPS hostname; no custom domain, public Route 53 hosted zone, public DNS record, or ACM certificate is used. Cloud Map still manages private service-discovery DNS inside the VPC.

## Onboard and plan

Run the supported onboarding command without deployment first:

```bash
infra/scripts/aws-onboard.sh dev \
  --config infra/aws/envs/dev.deploy.env
```

The script displays the resolved account and requires the operator to type its account ID. Use `--yes` only in an already controlled non-interactive environment.

The command is idempotent and performs the entire CLI-amenable sequence:

1. Verifies the named profile is non-root, the region matches the tfvars file, and the GitHub repository is accessible.
2. Creates or updates the monthly AWS Budget and its 80% actual-spend email alert.
3. Creates and hardens the S3 backend, initializes native S3 state locking, and imports the bucket resources into the bootstrap state.
4. Reuses an account-level GitHub Actions OIDC provider when one exists; otherwise creates it. It creates or reconciles the environment-scoped GitHub deployment role.
5. Reuses the logical `dev` GitHub Environment so the already-configured Google OAuth credentials are not duplicated, and sets every AWS variable required by the workflow.
6. Reconciles customer SSO through `aws-configure-customer-sso.sh`: it reuses the protected Google values, creates or updates the Microsoft personal-account registration through the authenticated CLI, and writes its generated credential directly to the protected GitHub Environment.
7. Initializes, formats, validates, and saves the account-backed application plan at `infra/aws/aws-dev.tfplan`; non-secret placeholders model the unreadable GitHub secrets without copying them locally.
8. When `--deploy` is present, dispatches `deploy.yml` for AWS/dev. The GitHub-hosted runner creates ECR, builds and pushes all four images, applies the stack, creates the AWS-generated CloudFront HTTPS endpoint, runs migrations, and smoke-tests it.

The initial non-deploying run prints the exact Cognito federation callback. Add it to the reused Google OAuth client as described below, review `infra/aws/aws-dev.tfplan`, and only then rerun with `--deploy`:

```bash
infra/scripts/aws-onboard.sh dev \
  --config infra/aws/envs/dev.deploy.env \
  --deploy
```

Existing state, OIDC, role, and GitHub variables are reconciled rather than recreated.

To reconcile or rotate customer SSO independently of onboarding, run:

```bash
infra/scripts/aws-configure-customer-sso.sh dev \
  --config infra/aws/envs/dev.deploy.env
```

It verifies that the existing protected Google client ID and secret are present,
creates or reconciles the dedicated Microsoft personal-account app through the
authenticated Microsoft CLI, stores its generated credential directly in the
same protected GitHub Environment, and updates AWS/GitHub deployment trust. It
does not print or persist either provider secret. The Cognito callback registered
at both providers is
`https://<cognito-prefix>.auth.<region>.amazoncognito.com/oauth2/idpresponse`.
Microsoft is reconciled through its CLI. Google does not expose an equivalent
supported CLI for editing an existing OAuth client's redirect URIs, so add that
exact URI once in Google Cloud Console under **APIs & Services → Credentials →
the reused OAuth 2.0 Client ID → Authorized redirect URIs**. Preserve every
existing authorized redirect URI on the reused client.

## Monitor and verify

```bash
set -a
source infra/aws/envs/dev.deploy.env
set +a

gh run list \
  --repo "$GITHUB_OWNER/$GITHUB_REPO" \
  --workflow deploy.yml \
  --limit 1

gh run watch <run-id> \
  --repo "$GITHUB_OWNER/$GITHUB_REPO" \
  --exit-status
```

The workflow requires the migration task to exit zero and `/health/ready` to return HTTP 200. After it succeeds, complete the browser and observability checks in the [AWS deployment workbook](../workbooks/aws-deployment-workbook.md#9-verification-evidence).

Google and Microsoft / Outlook are the only Cognito managed-login options. No
local Cognito user is provisioned. Real federated sign-in, callback,
authenticated API access, refresh, and logout are mandatory dev acceptance
gates; `Log in as Dev` is not a substitute.

Onboarding preserves the repository variable `DEPLOYMENT_TARGETS`; any legacy
entry in the local config is ignored with a notice. Set the repository variable
separately: `none` disables cloud push deployment, while `aws`, `azure`, or `both`
enables the chosen providers. Enabled non-`main` pushes target `dev`, and enabled
`main` pushes target `production`. Manual dispatch, including `--deploy`, still
works with push policy `none` and does not change it.

## Production

Create `infra/aws/envs/production.deploy.env` from the same example with the production Cognito prefix and committed deployment ref. Then run:

```bash
infra/scripts/aws-onboard.sh production \
  --config infra/aws/envs/production.deploy.env
```

Set `GITHUB_PRODUCTION_REVIEWER` to `user:<github-login>` or `team:<organization-team-slug>`. The script configures that reviewer and prevents self-review on the `production` GitHub Environment. Review `infra/aws/aws-production.tfplan` before rerunning with `--deploy`. The workbook's recovery and availability gates are optional for this disposable demo. The bootstrap IAM policy is intentionally broad; select only the intended demo account.

## Failure behavior

The script and workflow use `set -euo pipefail` and stop at the first failed gate. Rerun the same command after correcting the reported condition. Do not manually continue with later Terraform or AWS commands.

If an application revision fails after a successful database migration, use a forward-compatible application fix or the migration recovery decision in the workbook. Do not deploy an older image blindly against a changed schema.


## Decommission both application environments

Stopping RDS is not decommissioning: AWS automatically restarts a stopped database after seven days, and stopped database storage remains billable. Setting `DEPLOYMENT_TARGETS=none` prevents push deployments but does not delete resources. Check both `aws/dev.tfstate` and `aws/production.tfstate`.

Use `infra/scripts/aws-teardown.py` with explicit account, profile, region, bucket, and environment. Run `plan` first, review its deletion list, then run `apply` with the same arguments and work directory. This deletes application and identity data, including database automated backups and ECR images, under the disposable-demo policy. Bootstrap IAM and the versioned state bucket remain; S3 storage and requests can still incur small charges.

```bash
# Replace these values with the selected account and bootstrap outputs.
account=123456789012
profile=ea-bootstrap
region=us-east-1
bucket=your-state-bucket
environment=dev # Repeat with production to remove both environments.
work_dir="__logs/aws-teardown-$(date -u +%Y%m%dT%H%M%SZ)-${environment}"

python3 infra/scripts/aws-teardown.py plan \
  --account "$account" --profile "$profile" --region "$region" \
  --bucket "$bucket" --environment "$environment" --work-dir "$work_dir"

cat "$work_dir/approved-addresses.json"
terraform -chdir="$work_dir/root" show "$PWD/$work_dir/review.tfplan"

python3 infra/scripts/aws-teardown.py apply \
  --account "$account" --profile "$profile" --region "$region" \
  --bucket "$bucket" --environment "$environment" --work-dir "$work_dir"
```

The script copies the AWS Terraform root into the private work directory and rehydrates protected identity-provider inputs from the selected remote state. It rejects another account, mismatched environment tags, changed state, and plans containing creates or updates. Live ownership checks precede database deletion, ECR image removal, and load-balancer protection removal. Database deletion skips final snapshots and removes automated backups; Terraform refreshes and destroys the remaining state-owned resources. It never uses the Azure or bootstrap state.

Keep deployments and other Terraform writers idle during teardown. API preparation steps run between Terraform operations and do not hold the Terraform lock continuously. If teardown fails or is interrupted, inspect the error, then prepare a fresh plan in a new work directory; do not blindly reuse a stale plan. Existing manual snapshots and resources outside Terraform state require separate ownership review.

Work directories contain secrets in state, variable files, and binary plans. Keep them under ignored `__logs/`, restrict access, and never publish them. The script uses owner-only permissions for newly created files and directories.

After both environments finish, verify live inventory across all enabled regions:

```bash
python3 infra/scripts/aws-teardown-check.py \
  --account "$account" --profile "$profile"
```

The verifier fails if project databases, snapshots, retained automated backups, registries, EFS, alarms, logs, active secrets, clusters, load balancers, VPCs, NAT gateways, tagged public IPs or volumes, private namespaces, hosted zones, or CloudFront distributions remain. API failures also fail verification. It is scoped to the project's names and tags, not an exhaustive account billing audit. Historical ECS task-definition revisions and secrets pending deletion are not runtime workloads. Secrets scheduled for deletion are not charged during their recovery window.

Confirm that both remote application states contain no managed resources. Review Cost Explorer by service and region after its next refresh; it updates at least daily and some usage arrives later. Historical charges remain on the bill after deletion. Do not claim a zero account bill while preserving billable state storage or other account resources.

References: [RDS stop behavior](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_StopInstance.html), [Secrets Manager deletion billing](https://docs.aws.amazon.com/secretsmanager/latest/userguide/manage_delete-secret.html), [Cost Explorer refresh timing](https://docs.aws.amazon.com/cost-management/latest/userguide/ce-what-is.html).


### September 30, 2026 incident evidence

CloudTrail recorded `StopDBInstance` for both `ea-dev-postgres` and `ea-prod-postgres` on August 17 at approximately 19:07 UTC. Cost Explorer showed storage-only RDS charges on August 18–23, instance charges returning on August 24, and full-day instance charges from August 25. Both databases were `available` on September 30. This matches the seven-day automatic restart behavior; the previous shutdown was incomplete decommissioning.

Estimated unblended account cost for September 1–29 was $30.29, including $26.72 for RDS. Recent daily cost was approximately $1.04. Other charges included Secrets Manager, private Route 53 zones, CloudWatch alarms, ECR, EFS, and S3. Push deployment policy was already `none`, no deployment was running, and the September 20 workflow skipped AWS. The backend application states had last been written on August 16, before the manual stop operation.

Teardown completed September 30, 2026: the dev state was finalized at 12:40:10 UTC and production at 12:41:31 UTC. Both databases were deleted without retained backups, and Terraform destroyed another 84 managed resources per environment with no creates or updates. The final live verifier passed across all 17 enabled regions plus global CloudFront and Route 53 inventory at 12:43 UTC. Both application states contain zero managed resources. The bootstrap state remained unchanged from August 15; the versioned state bucket retained 28,622,015 bytes across 230 object versions. Production secrets remain marked for deletion under their existing recovery policy, without secret-storage charges during that window. Historical inactive-workload task-definition revisions can remain without running compute. This is resource-deletion evidence, not a claim that historical bills disappear or that preserved S3 state storage is free.

Private evidence is under ignored `__logs/aws-decommission-20260930/`, including billing responses, before/after state, reviewed plans, apply logs, and `inventory-final.json`. Do not publish the directory: state and plans contain credentials. Repository changes were left unstaged for operator review.
