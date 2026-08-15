# Bootstrap — one-off setup for CI/CD

This module provisions the Azure trust and state resources GitHub Actions needs to deploy `infra/azure/`. Run it once from an authenticated developer CLI with Owner, or Contributor plus User Access Administrator, on the target subscription.

It creates:

- A resource group and Storage Account plus private blob container for **remote Terraform state** (`azurerm` backend with versioning and retention). Local and CI Terraform authenticate with Entra ID; the workflow does not handle an account key or SAS token.
- An **Entra ID application + service principal** (`ea-github-oidc`) with federated credentials for the logical `dev` and `production` GitHub Environments—no client secrets or passwords.
- Role assignments: `Contributor` + `User Access Administrator` at subscription scope (UAA required because the root infra creates `AcrPull` and Key Vault RBAC assignments), and `Storage Blob Data Contributor` on the tfstate storage account.

State is **local and gitignored** (this module can't depend on itself).

## Prereqs

- `az login` as a user with **Owner** or **Contributor + User Access Administrator** on the target subscription. Application creation in the Entra ID tenant is also required.
- `gh auth login` with `repo` scope (used to transmit secrets into the repo once bootstrap finishes).
- `terraform >= 1.9`.

## Run it

```bash
cd /workspace/infra/azure/bootstrap

cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars. Set subscription_id, a unique 4-6 character
# name_suffix, the repository owner/name, and this exact environment list:
# github_environments = ["dev", "production"]

terraform init
terraform validate
terraform apply
```

## Wire the repo

```bash
# Pipe the rendered gh commands straight into bash — nothing is written to disk.
terraform output -raw gh_setup_commands | bash
```

The generated script creates the configured GitHub Environments. It stores the shared Azure OIDC values (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`) as repository secrets and the shared backend coordinates (`TFSTATE_RESOURCE_GROUP`, `TFSTATE_STORAGE_ACCOUNT`, `TFSTATE_CONTAINER`) as repository variables. Environment-scoped External ID credentials and the tenant subdomain are configured separately through the [Azure SSO runbook](../../../docs/runbooks/azure-sso-manual-bootstrap.md).

The current module default predates the logical environment migration. Do not rely on it: explicitly set `github_environments = ["dev", "production"]` before applying. The subjects must match the `environment:` value used by `.github/workflows/deploy-azure.yml` exactly.

If you want to sanity-check a value locally, `terraform output <name>` prints it. Put anything you want in your gitignored `/workspace/.env` — **never** into a file that git tracks.

## Outputs

| Output | Purpose |
|---|---|
| `azure_client_id` / `azure_tenant_id` / `azure_subscription_id` | Sensitive values written to repository secrets for OIDC. |
| `tfstate_resource_group` / `tfstate_storage_account` / `tfstate_container` | Repository variables used for backend configuration. |
| `backend_config_dev` / `backend_config_production` | Copy-paste snippets for local `terraform init -backend-config=...`. |
| `gh_setup_commands` | Rendered bash script — pipe into `bash`. |

## Teardown

Bootstrap resources are shared by all environments. Destroying them rips CI out of the repo — only do it if you're retiring the project.

```bash
terraform destroy
```

If you destroy, you must also:

1. Remove the repository secrets/variables (`gh secret delete` / `gh variable delete`).
2. Delete the GitHub Environments via the repo Settings UI or `gh api -X DELETE repos/<owner>/<repo>/environments/<name>`.
