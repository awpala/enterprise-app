#-------------------------------------------------------------------------
# Bootstrap — one-off Terraform the developer runs MANUALLY from the CLI
# to provision everything CI/CD needs:
#
#   - Resource group + Storage Account + blob container for remote tfstate
#   - Entra ID application + service principal with federated credentials
#     for GitHub Actions OIDC (per environment)
#   - Role assignments (Contributor + UAA at subscription scope, Storage
#     Blob Data Contributor on the tfstate account)
#   - Microsoft Graph app-role assignments on the CI SP so the root
#     infra's azuread provider can manage Entra External ID app regs
#
# State is LOCAL (see versions.tf) and gitignored. Outputs include
# `gh_setup_commands` which the user pipes into bash to populate repo
# secrets/variables/environments via the gh CLI.
#-------------------------------------------------------------------------

data "azurerm_subscription" "current" {}
data "azurerm_client_config" "current" {}
data "azuread_client_config" "current" {}

#-------------------------------------------------------------------------
# Microsoft Graph — the "resource app" the CI SP needs app-roles on so
# Terraform can manage app registrations (for Entra External ID).
# The client_id 00000003-0000-0000-c000-000000000000 is Microsoft Graph's
# well-known global app ID. Every tenant has a service principal for it.
#-------------------------------------------------------------------------
data "azuread_service_principal" "msgraph" {
  client_id = "00000003-0000-0000-c000-000000000000"
}

#-------------------------------------------------------------------------
# tfstate RG + storage account + container
#-------------------------------------------------------------------------
resource "azurerm_resource_group" "tfstate" {
  name     = var.tfstate_resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_storage_account" "tfstate" {
  # Name must be 3-24 lowercase alphanumerics, globally unique.
  name                     = "eatfstate${var.name_suffix}"
  resource_group_name      = azurerm_resource_group.tfstate.name
  location                 = azurerm_resource_group.tfstate.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  min_tls_version          = "TLS1_2"

  # Shared key auth stays enabled at the account level for operational
  # simplicity, but the Terraform backend + all CI flows use AAD (see
  # use_azuread_auth + use_oidc in infra/versions.tf). No key is ever
  # handled by a human or a workflow.
  public_network_access_enabled = true
  shared_access_key_enabled     = true

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 30
    }

    container_delete_retention_policy {
      days = 30
    }
  }

  tags = var.tags
}

resource "azurerm_storage_container" "tfstate" {
  name                  = var.tfstate_container_name
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}

#-------------------------------------------------------------------------
# Entra ID application + SP for GitHub Actions OIDC
#-------------------------------------------------------------------------
resource "azuread_application" "github_oidc" {
  display_name = var.oidc_app_display_name
  owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "github_oidc" {
  client_id = azuread_application.github_oidc.client_id
  owners    = [data.azuread_client_config.current.object_id]
}

# One federated credential per GitHub Environment. The `subject` here MUST
# match the `repo:<owner>/<repo>:environment:<name>` claim GitHub Actions
# emits when a job specifies `environment: <name>`.
resource "azuread_application_federated_identity_credential" "gh_env" {
  for_each = toset(var.github_environments)

  application_id = azuread_application.github_oidc.id
  display_name   = "github-${each.key}"
  description    = "GitHub Actions OIDC for ${var.github_owner}/${var.github_repo} environment:${each.key}"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_owner}/${var.github_repo}:environment:${each.key}"
}

#-------------------------------------------------------------------------
# Microsoft Graph app-role assignments on the CI SP.
#
# These grant the GitHub OIDC service principal the Graph permissions
# needed for the root infra's `azuread` provider (default alias,
# workforce tenant) to manage app registrations owned by the SP.
#
# NOTE: These only cover the workforce-tenant path. The External ID
# (`.external`) provider alias authenticates as a SEPARATE app
# registration inside the External ID tenant (client_id + secret
# delivered via TF_VAR_external_tenant_client_id /
# TF_VAR_external_tenant_client_secret). That app registration must be
# granted the same Graph permissions inside the External ID tenant, and
# admin-consented there. See the runbook for the one-time manual step.
#
# App-role IDs are Microsoft Graph constants:
#   Application.ReadWrite.OwnedBy = 18a4783c-866b-4cc7-a460-3d5e5662c884
#   IdentityProvider.ReadWrite.All = 90db2b9a-d928-4d33-a4dd-8442ae3d41e4
#
# After `terraform apply`, admin consent must be granted ONCE per tenant:
#   az ad app permission admin-consent --id <azure_client_id>
#-------------------------------------------------------------------------
resource "azuread_app_role_assignment" "graph_application_readwrite_ownedby" {
  principal_object_id = azuread_service_principal.github_oidc.object_id
  resource_object_id  = data.azuread_service_principal.msgraph.object_id
  app_role_id         = "18a4783c-866b-4cc7-a460-3d5e5662c884"
}

resource "azuread_app_role_assignment" "graph_identityprovider_readwrite_all" {
  principal_object_id = azuread_service_principal.github_oidc.object_id
  resource_object_id  = data.azuread_service_principal.msgraph.object_id
  app_role_id         = "90db2b9a-d928-4d33-a4dd-8442ae3d41e4"
}

#-------------------------------------------------------------------------
# Role assignments for the SP
#
# - Contributor + UAA at subscription scope: root infra creates role
#   assignments (AcrPull, Key Vault Secrets Officer/User) which require
#   User Access Administrator.
# - Storage Blob Data Contributor on the tfstate account: CI reads/writes
#   state via OIDC + AAD auth (backend use_oidc + use_azuread_auth).
#-------------------------------------------------------------------------
resource "azurerm_role_assignment" "sp_contributor" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.github_oidc.object_id
}

resource "azurerm_role_assignment" "sp_uaa" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "User Access Administrator"
  principal_id         = azuread_service_principal.github_oidc.object_id
}

resource "azurerm_role_assignment" "sp_tfstate_blob" {
  scope                = azurerm_storage_account.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.github_oidc.object_id
}

# Also grant the human running bootstrap the Storage Blob Data Contributor
# role so they can run `terraform init -migrate-state` locally against the
# new backend without the account key.
resource "azurerm_role_assignment" "human_tfstate_blob" {
  scope                = azurerm_storage_account.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}
