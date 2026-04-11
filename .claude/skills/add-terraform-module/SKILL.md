---
name: add-terraform-module
description: Creates a new Terraform module for an Azure resource concern.
disable-model-invocation: true
---

## Inputs

- **Module name** (e.g., `container-apps`, `postgres`)
- **Azure resources** it manages
- **Required inputs** from other modules (e.g., resource group, Log Analytics workspace ID)

## What It Produces

1. **Module directory** at `infra/modules/{module-name}/`
2. **`main.tf`** — resource definitions
3. **`variables.tf`** — all inputs with `description`, `type`, and `sensitive` where needed
4. **`outputs.tf`** — values other modules need (IDs, connection strings, endpoints)
5. **Module call** added to `infra/main.tf`

## Conventions Applied

- All resources tagged: `environment`, `project`, `managed-by = "terraform"`
- Variable names: `snake_case`, descriptive
- Use managed identities, never admin credentials or static keys
- Outputs expose only what other modules actually consume
- `terraform fmt` and `terraform validate` must pass
- Sensitive outputs marked `sensitive = true`
