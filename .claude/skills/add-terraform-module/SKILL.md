---
name: add-terraform-module
description: Creates a Terraform module inside the selected Azure or AWS provider implementation.
disable-model-invocation: true
---

## Inputs

- **Module name** (for example, `container-services`, `container-apps`, or `postgres`)
- **Deployment target** (`azure` or `aws`) and resources it manages
- **Required inputs** from other modules (for example, network IDs, a resource group, or observability destinations)

## What It Produces

1. **Module directory** at `infra/{provider}/modules/{module-name}/`
2. **`main.tf`** — resource definitions
3. **`variables.tf`** — all inputs with `description`, `type`, and `sensitive` where needed
4. **`outputs.tf`** — non-secret IDs, names, and endpoints that other modules need
5. **Module call** added to `infra/{provider}/main.tf`

## Conventions Applied

- All resources tagged: `environment`, `project`, `managed-by = "terraform"`
- Variable names: `snake_case`, descriptive
- Use Azure managed/workload identities or AWS IAM roles; never static deployment keys or registry admin credentials.
- Outputs expose only what other modules actually consume
- `terraform fmt` and `terraform validate` must pass
- Sensitive outputs marked `sensitive = true`
