#-------------------------------------------------------------------------
# Outputs.
#
# NOTE: These values are sensitive (tenant/subscription/client IDs are
# treated as secrets for this project). They live ONLY in local tfstate
# (gitignored) and are surfaced via `terraform output`. They must never
# be committed.
#-------------------------------------------------------------------------

output "azure_client_id" {
  description = "Client (application) ID of the GitHub OIDC service principal."
  value       = azuread_application.github_oidc.client_id
  sensitive   = true
}

output "azure_tenant_id" {
  description = "Entra ID tenant hosting the OIDC application."
  value       = data.azuread_client_config.current.tenant_id
  sensitive   = true
}

output "azure_subscription_id" {
  description = "Azure subscription the SP is scoped to."
  value       = data.azurerm_subscription.current.subscription_id
  sensitive   = true
}

output "tfstate_resource_group" {
  description = "Resource group holding the tfstate storage account."
  value       = azurerm_resource_group.tfstate.name
}

output "tfstate_storage_account" {
  description = "Storage account holding the tfstate blob container."
  value       = azurerm_storage_account.tfstate.name
}

output "tfstate_container" {
  description = "Blob container holding tfstate files."
  value       = azurerm_storage_container.tfstate.name
}

output "backend_config_dev" {
  description = "Copy-paste snippet for `terraform init -backend-config=...` for the dev environment."
  value = join(" ", [
    "-backend-config=resource_group_name=${azurerm_resource_group.tfstate.name}",
    "-backend-config=storage_account_name=${azurerm_storage_account.tfstate.name}",
    "-backend-config=container_name=${azurerm_storage_container.tfstate.name}",
    "-backend-config=key=dev.tfstate",
  ])
}

output "backend_config_production" {
  description = "Copy-paste snippet for `terraform init -backend-config=...` for the production environment."
  value = join(" ", [
    "-backend-config=resource_group_name=${azurerm_resource_group.tfstate.name}",
    "-backend-config=storage_account_name=${azurerm_storage_account.tfstate.name}",
    "-backend-config=container_name=${azurerm_storage_container.tfstate.name}",
    "-backend-config=key=production.tfstate",
  ])
}

#-------------------------------------------------------------------------
# gh_setup_commands — a ready-to-run bash script that wires the repo up.
#
# Usage:
#   terraform output -raw gh_setup_commands | bash
#
# All secret values are substituted from the outputs above via Terraform,
# so nothing sensitive hits the shell history through this file itself.
# The caller must be `gh auth login`'d with the `repo` scope.
#-------------------------------------------------------------------------
output "gh_setup_commands" {
  description = "Bash commands to populate GitHub repo secrets, variables, and Environments required by the CI/CD workflows."
  sensitive   = true
  value = templatefile("${path.module}/templates/gh_setup.sh.tftpl", {
    repo                    = "${var.github_owner}/${var.github_repo}"
    environments            = var.github_environments
    azure_client_id         = azuread_application.github_oidc.client_id
    azure_tenant_id         = data.azuread_client_config.current.tenant_id
    azure_subscription_id   = data.azurerm_subscription.current.subscription_id
    tfstate_resource_group  = azurerm_resource_group.tfstate.name
    tfstate_storage_account = azurerm_storage_account.tfstate.name
    tfstate_container       = azurerm_storage_container.tfstate.name
  })
}
