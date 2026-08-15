# Multi-cloud infrastructure

The infrastructure tree has two peer Terraform implementations behind one
deployment contract:

- `azure/` provisions the Azure implementation.
- `aws/` provisions the AWS implementation.
- `scripts/deploy.sh` is the cloud-neutral CLI entry point.

Choose the cloud at deployment time; application code does not expose a cloud
selector to end users.

```bash
# Validate without credentials
./infra/scripts/deploy.sh validate azure
./infra/scripts/deploy.sh validate aws

# Plan/apply after the provider-specific bootstrap and login
./infra/scripts/deploy.sh plan aws dev
./infra/scripts/deploy.sh apply azure production
```

Both roots publish a normalized output surface consumed by deployment tooling:
`application_url`, `api_url`, `container_registry`, `migration_workload`,
`auth_authority`, `auth_client_id`, and `auth_api_scope`. Provider-specific
outputs remain available for operational commands.

The Terraform states are intentionally separate. A cloud switch creates a peer
deployment; it never attempts to reinterpret Azure resource addresses as AWS
resource addresses or vice versa.

## Provider mapping

| Capability | Azure implementation | AWS implementation |
|---|---|---|
| Container runtime | Container Apps / Jobs | ECS on Fargate / one-off tasks |
| Registry | Azure Container Registry | Elastic Container Registry |
| PostgreSQL | Flexible Server | RDS for PostgreSQL |
| Messaging | RabbitMQ Container App | RabbitMQ ECS service with EFS |
| Secrets | Key Vault | Secrets Manager |
| Customer identity | Entra External ID | Cognito user pools |
| UI runtime / entry point | Next.js on Container Apps | Next.js on ECS behind an Application Load Balancer |
| Logs/dashboard | Log Analytics + Application Insights workbooks | CloudWatch Logs + dashboard |
| CI federation | Entra workload identity | IAM GitHub OIDC role |
| State | Azure Blob | S3 native state locking |

See the provider READMEs and the [AWS deployment workbook](../docs/workbooks/aws-deployment-workbook.md)
for prerequisites, phase gates, and operational verification.

## CI/CD selection

`.github/workflows/deploy.yml` is the common delivery entry point. It never assumes a provider: dispatches require a target input, and push deployments require `DEPLOYMENT_TARGETS=azure`, `aws`, or `both`. The entry workflow calls the reusable `deploy-azure.yml` and `deploy-aws.yml` adapters and passes one normalized change set to each selected target.

Provider credentials, state coordinates, and approval rules belong to the explicitly named `azure-{environment}` and `aws-{environment}` GitHub Environments. Common scripts require `TF_ROOT`; they do not default to either provider.
