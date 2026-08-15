# AWS deployment workbook

## Purpose and status

This workbook records the evidence, risks, rollback points, and production gates for the AWS implementation. The command sequence lives in the scripted [AWS deployment runbook](../runbooks/aws-deployment.md); this document remains CLI-first so another operator can reproduce and review the result without an ad hoc console procedure.

Current status: **development implementation deployed and repeatedly verified**. The dedicated account, IAM Identity Center administrator, remote state, GitHub OIDC trust, Terraform application stack, generated CloudFront HTTPS origin, migrations, smoke tests, and Google plus Microsoft/Outlook browser SSO are implemented. Production remains blocked on the unchecked readiness gates in section 11, particularly least-privilege review, recovery exercises, load/capacity evidence, and operational handoff.

## 1. Baseline inventory and mapping

| Responsibility | Azure peer | AWS implementation | Evidence required |
|---|---|---|---|
| State bootstrap | Azure Blob container | Versioned encrypted S3 bucket with native lock file | Bootstrap outputs and state-lock contention test |
| CI trust | Entra federated credential | GitHub OIDC provider and environment-scoped IAM role | Successful `sts:GetCallerIdentity` from GitHub |
| Network | Container Apps-managed network plus public PaaS endpoints | CloudFront HTTPS, CloudFront-restricted ALB, two/three AZ VPC, private ECS/RDS/EFS, NAT | VPC diagram, reachability analysis, ALB ingress restricted to the CloudFront origin-facing prefix list, and no public task/RDS access |
| Registry | ACR, immutable deployment tags | Four ECR repositories, immutable tags, scan-on-push | Scan report and tag rejection test |
| Runtime | Container Apps and Job | Autoscaled Fargate services and one-off task | Stable services, target-tracking activity, health checks, migration exit code |
| UI | Next.js Container App on 3000 | Next.js ECS task on 3000 | Same image digest in both provider registries |
| Database | PostgreSQL Flexible Server | RDS PostgreSQL 16 | TLS connection, backup/restore evidence |
| Broker | RabbitMQ 4 Container App | RabbitMQ 4 Fargate service, Cloud Map, EFS | Restart persistence and topology verification |
| Secrets | Key Vault references | Secrets Manager task injection | No plaintext in task definitions, logs, plans, or Terraform outputs; restricted encrypted state |
| Identity | Entra External ID | Cognito user pool | Client-by-client sign-in/sign-out/token evidence |
| Telemetry | Azure Monitor adapter | OTLP to ADOT, CloudWatch/X-Ray | Correlated API-to-worker trace and dashboard screenshot |

## 2. Required decisions and captured inputs

Record these before the first bootstrap:

| Input | Dev | Production | Owner / evidence |
|---|---|---|---|
| AWS account ID | Verified dedicated account | Same dedicated account unless separated before production | Verified with non-root `sts:GetCallerIdentity` |
| Region | Configured in the ignored deploy environment and committed tfvars | Must be explicitly approved | `aws sts get-caller-identity` plus region preflight |
| GitHub organization/repository | Read from the deploy environment | Same repository, explicit per config | `gh repo view` and script preflight |
| State bucket name | Provisioned | Reuse the shared bootstrap bucket with a separate production state key | Bootstrap output; never hardcode here |
| Deployment role ARN | Provisioned | Provision through the production bootstrap | Bootstrap output; never hardcode here |
| VPC CIDR | `10.40.0.0/16` | Must be non-overlapping | Network approval |
| Public application origin | AWS-generated CloudFront URL | AWS-generated CloudFront URL | Terraform output |
| Cognito domain prefix | Configured | Required before production onboarding | Uniqueness check |
| Google OAuth credentials | Existing protected `dev` values | Existing protected `production` values | Secret names and callback test; never print values |
| Microsoft personal-account OIDC | Scripted app registration | Scripted app registration | Fixed consumer issuer, protected credential, callback test |
| Budget/alert threshold | Configured by onboarding | Required before production onboarding | AWS Budget identifier |

## 3. Authentication parity matrix

| Client/sign-in type | Azure behavior | AWS target | Implementation state | Production gate |
|---|---|---|---|---|
| Native Cognito account | Not part of the application flow | Disabled on the app client | Implemented | Managed login must offer only the required federated providers |
| Google | Portal-managed Entra federation | Required Cognito Google IdP | Implemented in Terraform; credentials protected | Exact callback, claim mapping, logout test |
| Microsoft account | Customer Microsoft identity | Required Cognito OIDC provider pinned to the Microsoft consumer tenant | Implemented in Terraform; credentials protected | Outlook personal-account callback, claim mapping, logout test |
| Enterprise OIDC | Entra federation | Optional Cognito OIDC IdP | Terraform input exists | Discovery, signing-key rotation, claim mapping test |
| Enterprise SAML | Entra federation | Optional Cognito SAML IdP | Terraform input exists | Metadata, signature, attribute, and IdP logout tests |
| Local developer | Synthetic opt-in | Same synthetic opt-in | Implemented | Confirm disabled in production |
| Demo guest | Synthetic opt-in | Same synthetic opt-in | Implemented | Written risk acceptance or disable |

The parity goal is equivalent business access, not identical provider screens. Do not mark AWS production-ready while a required client type is `Not implemented` or lacks browser and API evidence.

## 4. Workstation and account preflight

```bash
set -a
source infra/aws/envs/dev.deploy.env
set +a

terraform version
aws --version
node --version
dotnet --version
gh --version

aws sts get-caller-identity
aws ec2 describe-availability-zones \
  --region "$AWS_REGION" \
  --query 'AvailabilityZones[?State==`available`].[ZoneName,ZoneId]' \
  --output table
```

Expected: Terraform 1.9 or newer, a non-root authenticated AWS identity in the dedicated account, at least two available AZs, Node compatible with Next.js 16, .NET 10, and an authenticated GitHub CLI. Docker is intentionally unavailable in `ea-dev-env`; the GitHub-hosted deployment runner builds all images.

Check service quotas before applying: VPCs, Elastic IPs/NAT gateways, Fargate tasks, ALBs, target groups, RDS instances, EFS, ECR, Cognito user pools/domains, and Secrets Manager. Capture the quota output or support cases in this workbook.

## 5. Bootstrap remote state and GitHub trust

Use the single scripted procedure in the [AWS deployment runbook](../runbooks/aws-deployment.md). `infra/scripts/aws-onboard.sh` creates and hardens the S3 bucket, imports it into the remote bootstrap state, reconciles GitHub OIDC and the deployment role, and records the GitHub Environment variables. Do not run the bootstrap Terraform root manually; its partial S3 backend depends on the script's create/import ordering.

Capture the state bucket and role ARN emitted by the script. The script creates the selected GitHub Environment and sets its deployment role, state, region, and Cognito variables. The dispatched environment-scoped workflow verifies OIDC by assuming that role before any Terraform operation.

Terraform state contains generated database and broker credentials because Terraform creates the secret versions. Treat the versioned, encrypted state bucket as a secret store: block public access, restrict read access to the deployment role and break-glass operators, log access, and never publish state or unredacted plan artifacts.

Gate: review the bootstrap IAM policy before attaching it to production. Use CloudTrail from a development apply to derive a least-privilege policy and separate plan from apply if organizational controls require it.

## 6. Validate and plan the application stack

Copy `infra/aws/envs/dev.deploy.env.example` to the ignored `dev.deploy.env`, fill in its non-secret values, and run `infra/scripts/aws-onboard.sh dev --config infra/aws/envs/dev.deploy.env` without `--deploy`. Terraform generates the CloudFront HTTPS origin, the script configures all remaining inputs, and it saves the account-backed plan as `infra/aws/aws-dev.tfplan`.

Run `infra/scripts/aws-configure-customer-sso.sh` before planning. It reuses the
existing protected Google secrets and creates the Microsoft personal-account
registration through the authenticated CLI. Both providers are required inputs;
the workflow fails before Terraform if any credential is absent. Never commit
provider credentials to a deploy config or tfvars file.

Review the plan for:

- only the intended account/region;
- two public and two private subnets;
- no public IP on ECS services or RDS;
- encrypted RDS/EFS/S3 and immutable ECR repositories;
- secret values marked sensitive;
- dev-only single NAT and production per-AZ NAT;
- production RDS Multi-AZ and deletion/backup settings appropriate for approval;
- Cognito callback/logout URLs matching the final HTTPS origin;
- no unexpected replacement of persistent resources.

Save a redacted plan JSON and policy-scan result as CI artifacts.

## 7. Build and push immutable images

The GitHub-hosted AWS adapter creates ECR first, then builds and pushes API, migrations, data-engine, and UI images from the single committed `DEPLOY_REF`. Do not build or push deployment images from `ea-dev-env`.

Record all four image digests and ECR scan findings. Deploy digests/tags from one commit only.

## 8. Apply and migrate

After reviewing the saved plan, rerun the same onboarding command with `--deploy`. It dispatches the cloud-neutral `deploy.yml` workflow with an explicit AWS target. The AWS adapter performs registry-first apply, four-image build/push, full apply with an AWS-generated CloudFront URL, migration task, smoke test, and retention. The onboarding config also sets `DEPLOYMENT_TARGETS`: non-`main` pushes deploy dev, and `main` pushes deploy production.

Gate: migration exit code is zero before application smoke tests. Never automatically roll back a successfully applied database migration by redeploying an older image; use forward-compatible migrations and the documented database recovery decision.

## 9. Verification evidence

```bash
APP_URL=$(terraform -chdir=infra/aws output -raw application_url)
CLUSTER=$(terraform -chdir=infra/aws output -raw ecs_cluster_name)
curl --fail --retry 12 --retry-delay 10 "$APP_URL/api/health"
curl --fail --retry 12 --retry-delay 10 "$APP_URL/api/runtime-config"
curl --fail --retry 12 --retry-delay 10 "$APP_URL/health/ready"

aws ecs list-services --cluster "$CLUSTER"
aws ecs describe-services --cluster "$CLUSTER" \
  --services ea-dev-ui ea-dev-api ea-dev-data-engine ea-dev-rabbitmq
aws rds describe-db-instances --query 'DBInstances[].{id:DBInstanceIdentifier,public:PubliclyAccessible,status:DBInstanceStatus}'
```

Complete real Google and Microsoft / Outlook browser journeys, including token
inspection (`iss`, `client_id`, `scope`, `token_use`), creating a model,
requesting a run, observing completion, refresh, logout, and revoked/expired-token
rejection. Confirm the audit actor and message headers contain normalized
subject/tenant/provider values. No local Cognito account is provisioned.

In CloudWatch/X-Ray, capture a correlated trace spanning ALB/API, RabbitMQ publish/consume, and data engine. Confirm alarms are `OK`, log retention matches tfvars, and no secret appears in logs.

## 10. Failure, rollback, and teardown

- **Bad application revision before stabilization:** ECS deployment circuit breakers roll the service back to its previous task definition.
- **Bad application revision after stabilization:** deploy a forward fix. If an application rollback is schema-compatible, restore the retained manifest or digest under a new immutable tag and apply that tag; the cleanup job removes old tags, so do not assume a historical tag still exists.
- **Migration failure before schema change:** inspect the migration log stream, correct configuration/image, and rerun the one-off task.
- **Migration failure after schema change:** stop application rollout and follow the migration's forward-fix or database restore plan. Do not improvise destructive SQL.
- **Identity failure:** keep synthetic modes disabled in production; restore the prior app client/provider configuration from Terraform and verify exact redirect URIs.
- **Broker failure:** capture logs and EFS state before replacement. Validate queue durability and replay semantics.
- **RDS recovery:** restore to a new instance, validate it, then rotate the connection-string secret and redeploy tasks.

There is not yet a supported scripted teardown adapter that rehydrates the exact backend and protected identity-provider inputs. Do not substitute an ad hoc sequence of partial AWS/Terraform commands. Adding and exercising that script is a production gate. Production teardown also requires an explicit change record, retained RDS snapshot, retained logs as required, and Secrets Manager recovery-window review.

## 11. Production readiness checklist

- [ ] Dedicated AWS accounts and environment isolation approved.
- [ ] Account-backed plans contain no policy/security critical findings.
- [ ] IAM reduced from bootstrap permissions to observed least privilege.
- [ ] AWS Budgets and cost anomaly detection configured.
- [ ] CloudFront default TLS and generated-hostname callback/logout URLs verified; no custom DNS or operator-managed ACM certificate is configured.
- [ ] Required SSO client types pass the parity matrix.
- [ ] Synthetic dev and guest authentication are disabled or formally accepted.
- [ ] RDS Multi-AZ, backups, restore drill, maintenance, and deletion protection approved.
- [ ] RabbitMQ persistence/restart test passes; HA limitation accepted or Amazon MQ selected.
- [ ] Load test demonstrates ECS scaling, ALB health, RDS capacity, and NAT sufficiency.
- [ ] CloudWatch/X-Ray correlation and alert routing verified.
- [ ] Image scans meet policy; base-image update ownership exists.
- [ ] Migration failure and application rollback exercises pass.
- [ ] Runbook executed by an operator other than its author.

## 12. Evidence log

| Date | Environment | Commit/image digests | Activity | Result / artifact |
|---|---|---|---|---|
| 2026-08-15 | Development | Feature branch immutable images | Account bootstrap, Terraform apply, migration, smoke test, and repeated push deployment | Passed; verify current run with `gh run list --workflow deploy.yml` |
| 2026-08-15 | Development | Deployed application | Google and Microsoft/Outlook sign-in, callback, authenticated API access, logout, and model workflow | Passed interactively; no credentials or generated URLs recorded here |
| Pending | Production | — | Security, recovery, load, alert-routing, and independent-operator gates | Not approved |
