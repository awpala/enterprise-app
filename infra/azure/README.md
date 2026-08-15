# Azure Terraform implementation

This directory contains the Azure peer of `infra/aws`. It owns Azure-specific state, bootstrap, environment values, and modules; cloud-neutral orchestration remains in `infra/scripts`.

## Mapping

| Responsibility | Azure implementation |
|---|---|
| UI/API/worker/broker | Azure Container Apps |
| Migrations | Container Apps Job |
| Images | Azure Container Registry |
| Database | PostgreSQL Flexible Server |
| Secrets | Key Vault |
| Identity | Entra External ID app registrations |
| Telemetry | Application Insights and Log Analytics |
| CI identity | Entra workload identity |
| State | Azure Blob Storage |

The Next.js UI is a standalone container on port 3000. Terraform computes its Container Apps FQDN before registering Entra callback/logout URLs. The UI receives `AUTH_PROVIDER=entra`; the API receives the normalized `Authentication:*` contract.

## Bootstrap

```bash
cd /workspace/infra/azure/bootstrap
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

Create the External ID tenant and Terraform service principal using the [Azure SSO runbook](../../docs/runbooks/azure-sso-manual-bootstrap.md), then export the required `ARM_*` and `TF_VAR_external_tenant_*` credentials.

## Validate, plan, and apply

```bash
cd /workspace
export TFSTATE_RESOURCE_GROUP='<bootstrap-output>'
export TFSTATE_STORAGE_ACCOUNT='<bootstrap-output>'
export TFSTATE_CONTAINER='<bootstrap-output>'

infra/scripts/deploy.sh validate azure dev
infra/scripts/deploy.sh plan azure dev
infra/scripts/deploy.sh apply azure dev
```

Deployment is two phase because images cannot be built into ACR until the registry exists:

1. Target the resource group and `module.acr`.
2. Build `ea-api`, `ea-migrations`, `ea-data-engine`, and `ea-ui` with one immutable tag.
3. Apply the full stack with that tag.
4. Start the migration job and require a successful completion.
5. Verify the UI health endpoint, API readiness, OIDC, and a model-run workflow.

The cloud-neutral `.github/workflows/deploy.yml` entry point calls `.github/workflows/deploy-azure.yml` only when Azure is explicitly selected.

## State-layout migration

Tracked Azure configuration moved from `infra/` to `infra/azure/`. Existing remote state remains valid because resource addresses inside the root are unchanged. Initialize the new working directory against the same backend key before planning and confirm the plan does not recreate the whole environment. Root-level `moved` blocks preserve the Container Apps environment, shared identity, and ACR pull assignment that moved out of the application module.
