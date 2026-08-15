# ADR 0002 - AWS peer architecture

## Status

Proposed. 2026-08-15. Account-backed planning and deployment validation remain pending because no dedicated AWS account is available.

## Context

The application previously expressed one Azure-native deployment: Container Apps, Static Web Apps, PostgreSQL Flexible Server, ACR, Key Vault, Entra External ID, and Azure Monitor. AWS must become a supported deployment target without changing the system-of-record boundary, message contracts, container behavior, or customer SSO expectations.

The first AWS implementation must be close enough to the Azure design that operators can compare responsibilities directly. It must also expose CLI-first bootstrap, deployment, migration, verification, rollback, and teardown procedures. It cannot claim production readiness until an account-backed plan, security review, load test, and recovery exercise are complete.

## Decision

Implement AWS as a peer Terraform root under `infra/aws`, with its own S3 state and AWS provider lock file. Use the following capability mapping:

| Capability | Azure | AWS |
|---|---|---|
| Web/API/worker runtime | Container Apps | ECS services on Fargate |
| One-off migrations | Container Apps Job | ECS one-off task |
| Public routing | Container Apps ingress | Application Load Balancer |
| UI | Next.js Container App | Next.js ECS service |
| PostgreSQL | Flexible Server | RDS PostgreSQL 16 |
| Images | ACR | ECR |
| Secrets | Key Vault | Secrets Manager |
| Customer identity | Entra External ID | Cognito user pool and managed login |
| Messaging | RabbitMQ container | RabbitMQ ECS service with encrypted EFS |
| Service discovery | Container Apps environment DNS | AWS Cloud Map private DNS |
| Logs/APM | Log Analytics and Application Insights | CloudWatch, X-Ray, and ADOT sidecars |
| CI identity | Entra workload identity | IAM role trusted through GitHub OIDC |

Use a two-to-three-AZ VPC. Place the ALB in public subnets and ECS, RDS, RabbitMQ, and EFS in private subnets. Use one NAT gateway in development and one per AZ in production. Encrypt RDS, EFS, ECR, Secrets Manager, and S3 state using AWS-managed encryption for the prototype; revisit customer-managed keys during hardening.

Use one ALB origin for the Next.js UI and API. Route `/api/v1/*`, health, OpenAPI, and Scalar paths to the API; route all other paths to Next.js. HTTP is sufficient for an accountless Terraform prototype. Any deployed OIDC flow requires a stable HTTPS origin, validated ACM certificate, matching DNS alias, and exact Cognito callback/logout registration.

Use Cognito Authorization Code flow with PKCE and a public client. Cognito native email/password is the baseline client type. Google, one generic upstream OIDC provider, and one metadata-driven SAML provider are optional Terraform inputs. Passwordless email OTP is not declared equivalent: Cognito managed login does not provide the same experience with this configuration, so it remains a tracked parity gate.

## Consequences

### Positive

- Azure and AWS have explicit, reviewable responsibility mapping.
- All application containers, including Next.js, are identical across clouds.
- ECS tasks emit standard OTLP to ADOT; application instrumentation is not coupled to AWS SDKs.
- State, credentials, and blast radius remain separate between providers.
- GitHub can deploy without long-lived AWS access keys.

### Negative and follow-up gates

- RabbitMQ remains self-managed on both clouds. EFS improves persistence on AWS but does not make the single broker highly available. Amazon MQ was not selected because it changes broker administration and topology behavior; evaluate it before production.
- NAT gateways, ALB, RDS, EFS, CloudWatch ingestion, and continuously running Fargate tasks create a meaningful idle cost.
- The bootstrap IAM policy is intentionally broad enough for first planning. Replace it with permissions derived from CloudTrail before production.
- HTTPS depends on DNS and a validated ACM certificate supplied by the operator; Route 53 zone ownership is not assumed.
- Cognito federation and logout behavior need end-to-end browser tests for every enabled identity provider.
- No AWS resource in this ADR has yet been applied. The workbook gates promotion on account-backed evidence.

## Alternatives considered

- **EKS:** rejected for the prototype because Kubernetes adds cluster operations without changing the application shape.
- **App Runner:** rejected because the private worker, RabbitMQ, EFS, migration task, and shared routing requirements align more directly with ECS.
- **Amazon MQ:** deferred. It may improve broker operations, but RabbitMQ-in-container is the closest behavioral match for initial parity.
- **Aurora PostgreSQL:** deferred because RDS PostgreSQL is the closer like-for-like baseline and has a lower minimum footprint.
