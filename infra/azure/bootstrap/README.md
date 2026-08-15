# Bootstrap — one-off setup for CI/CD

This module provisions **everything GitHub Actions needs** to deploy the root infra (`infra/`). It is run **once, manually, from a developer CLI** with Owner (or Contributor + User Access Administrator) on the target subscription.

It creates:

- A resource group and Storage Account + blob container for **remote Terraform state** (`azurerm` backend, versioned, AAD-auth only — no account keys).
- An **Entra ID application + service principal** (`ea-github-oidc`) with federated credentials for `azure-dev` and `azure-production` GitHub Environments—no client secrets or passwords.
- Role assignments: `Contributor` + `User Access Administrator` at subscription scope (UAA required because the root infra creates `AcrPull` and Key Vault RBAC assignments), and `Storage Blob Data Contributor` on the tfstate storage account.

State is **local and gitignored** (this module can't depend on itself).

## Prereqs

- `az login` as a user with **Owner** or **Contributor + User Access Administrator** on the target subscription. Application creation in the Entra ID tenant is also required.
- `gh auth login` with `repo` scope (used to transmit secrets into the repo once bootstrap finishes).
- `terraform >= 1.9`.

## Run it

```bash
cd /workspace/infra/azure/azure/bootstrap

cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars — set subscription_id and a unique 4-6 char name_suffix

terraform init
terraform validate
terraform apply
```

## Wire the repo

```bash
# Pipe the rendered gh commands straight into bash — nothing is written to disk.
terraform output -raw gh_setup_commands | bash
```

This populates repo secrets (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`), repo variables (`TFSTATE_RESOURCE_GROUP`, `TFSTATE_STORAGE_ACCOUNT`, `TFSTATE_CONTAINER`), and creates the `azure-dev` / `azure-production` GitHub Environments.

If you want to sanity-check a value locally, `terraform output <name>` prints it. Put anything you want in your gitignored `/workspace/.env` — **never** into a file that git tracks.

## Outputs

| Output | Purpose |
|---|---|
| `azure_client_id` / `azure_tenant_id` / `azure_subscription_id` | Repo secrets (OIDC). |
| `tfstate_resource_group` / `tfstate_storage_account` / `tfstate_container` | Repo variables (backend config). |
| `backend_config_dev` / `backend_config_production` | Copy-paste snippets for local `terraform init -backend-config=...`. |
| `gh_setup_commands` | Rendered bash script — pipe into `bash`. |

## Teardown

Bootstrap resources are shared by all environments. Destroying them rips CI out of the repo — only do it if you're retiring the project.

```bash
terraform destroy
```

If you destroy, you must also:

1. Remove the repo secrets/variables (`gh secret delete` / `gh variable delete`).
2. Delete the GitHub Environments via the repo Settings UI or `gh api -X DELETE repos/<owner>/<repo>/environments/<name>`.
