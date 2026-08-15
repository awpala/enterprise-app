# AWS Terraform prototype

This stack is the AWS peer of `infra/azure`, not an extension of it. Shared deployment orchestration lives in `infra/scripts`; each provider directory owns only provider-specific resources and state.

The prototype provisions a VPC, public/private subnets, NAT, ECR, ECS/Fargate, an ALB, an AWS-generated CloudFront HTTPS endpoint, RDS PostgreSQL, Cognito, Secrets Manager, EFS-backed RabbitMQ, CloudWatch, X-Ray export through ADOT, and an ECS migration task.

## Module boundaries

The root composes focused modules and owns only cross-module wiring plus generated credentials. Every module follows the repository convention of separate `main.tf`, `variables.tf`, and `outputs.tf` files.

| Module | Responsibility |
|---|---|
| `networking` | VPC, availability-zone subnet pairs, internet gateway, NAT, and routes |
| `container-registry` | Environment-scoped ECR repositories and lifecycle policies |
| `load-balancer` | ALB, listeners, routing rules, target groups, and ingress security group |
| `cloudfront` | AWS-generated HTTPS application endpoint and uncached ALB proxy |
| `ecs-cluster` | ECS cluster, Cloud Map namespace, and shared task network policy |
| `ecs-iam` | Task execution/task roles and narrowly scoped secret/telemetry permissions |
| `postgres` | RDS PostgreSQL, subnet group, and database network policy |
| `cognito` | User pool, API scope, public PKCE client, managed login, Google/Microsoft federation, and passwordless email OTP |
| `secrets-manager` | PostgreSQL connection string and RabbitMQ credential storage |
| `observability` | CloudWatch log groups, alarms, and operations dashboard |
| `rabbitmq` | EFS persistence, Cloud Map registration, task definition, and ECS service |
| `container-services` | API, UI, worker ECS services, CPU target tracking, and the one-off migration task definition |

ECR repositories include the environment prefix, so independent dev and production Terraform states never claim the same repository.

No AWS account was available while this prototype was authored. `terraform validate` is enforced locally, but the first account-backed plan and apply must work through the readiness gates in the [AWS deployment workbook](../../docs/workbooks/aws-deployment-workbook.md).

## Deployment

```bash
cd /workspace
cp infra/aws/envs/dev.deploy.env.example infra/aws/envs/dev.deploy.env
# Edit the non-secret deployment configuration, then run:
infra/scripts/aws-onboard.sh dev \
  --config infra/aws/envs/dev.deploy.env \
  --deploy
```

The onboarding script is the supported first-deployment entry point. It creates and imports the partial S3 backend, configures GitHub OIDC and environment variables, saves an account-backed application plan, and optionally dispatches the GitHub-hosted build/deployment workflow. Run `infra/scripts/aws-configure-customer-sso.sh` once before deployment to reuse the protected Google registration and reconcile Microsoft/Outlook SSO. Docker is not required in the devcontainer.

See the [AWS deployment runbook](../../docs/runbooks/aws-deployment.md) for the one-time browser prerequisites, configuration fields, production gates, and failure behavior.

The deployment config supplies only a globally unique Cognito prefix. Terraform generates the CloudFront HTTPS hostname and uses it directly for Cognito callback/logout URLs, CORS, UI runtime configuration, outputs, and smoke tests. No custom domain, Route 53 hosted zone, DNS record, or ACM certificate is required.
