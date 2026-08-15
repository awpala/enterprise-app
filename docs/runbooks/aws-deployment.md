# AWS deployment runbook

This is the operational path for onboarding and deploying the application to AWS. The detailed [AWS deployment workbook](../workbooks/aws-deployment-workbook.md) is an evidence and production-readiness checklist, not a command sequence.

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
DEPLOYMENT_TARGETS=aws
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

The onboarding script sets the repository variable `DEPLOYMENT_TARGETS` from
the deployment config. With `DEPLOYMENT_TARGETS=aws`, every non-`main` push
deploys to the protected `dev` environment, while every `main` push deploys to
the protected `production` environment.
Manual dispatch remains available for an explicitly selected environment.

## Production

Create `infra/aws/envs/production.deploy.env` from the same example with the production Cognito prefix and committed deployment ref. Then run:

```bash
infra/scripts/aws-onboard.sh production \
  --config infra/aws/envs/production.deploy.env
```

Set `GITHUB_PRODUCTION_REVIEWER` to `user:<github-login>` or `team:<organization-team-slug>`. The script configures that reviewer and prevents self-review on the `production` GitHub Environment. Review `infra/aws/aws-production.tfplan` and satisfy every production gate in the workbook before rerunning with `--deploy`. The bootstrap IAM policy is intentionally broad for the first account-backed dev deployment and must be reduced from CloudTrail evidence before production.

## Failure behavior

The script and workflow use `set -euo pipefail` and stop at the first failed gate. Rerun the same command after correcting the reported condition. Do not manually continue with later Terraform or AWS commands.

If an application revision fails after a successful database migration, use a forward-compatible application fix or the migration recovery decision in the workbook. Do not deploy an older image blindly against a changed schema.
