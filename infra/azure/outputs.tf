#-------------------------------------------------------------------------
# Values a human needs after `terraform apply`.
#-------------------------------------------------------------------------

output "resource_group_name" {
  description = "Resource group holding all deployed resources."
  value       = azurerm_resource_group.this.name
}

output "acr_name" {
  description = "ACR name. Use with: az acr build --registry <this> --image <repo>:<tag> --file <Dockerfile> <context>"
  value       = module.acr.name
}

output "acr_login_server" {
  description = "ACR login server (e.g. eadevacrxxxx.azurecr.io)."
  value       = module.acr.login_server
}

output "key_vault_name" {
  description = "Key Vault name (holds postgres + rabbitmq passwords)."
  value       = module.key_vault.name
}

output "postgres_fqdn" {
  description = "Postgres server FQDN."
  value       = module.postgres.fqdn
}

output "postgres_database" {
  description = "Application database name."
  value       = module.postgres.database_name
}

output "postgres_admin_username" {
  description = "Postgres admin login (password is in Key Vault as 'postgres-admin-password')."
  value       = module.postgres.administrator_login
}

output "api_url" {
  description = "Public HTTPS URL of the API Container App."
  value       = try(module.container_apps.api_url, null)
}

output "api_fqdn" {
  description = "Public FQDN of the API Container App."
  value       = try(module.container_apps.api_fqdn, null)
}

output "api_app_name" {
  description = "Container App name for the API."
  value       = try(module.container_apps.api_app_name, null)
}

output "data_engine_app_name" {
  description = "Container App name for the data engine."
  value       = try(module.container_apps.data_engine_app_name, null)
}

output "migrations_job_name" {
  description = "Container App Job name for EF Core migrations. Run with: az containerapp job start --name <this> --resource-group <rg>"
  value       = try(module.container_apps.migrations_job_name, null)
}

#-------------------------------------------------------------------------
# Entra External ID — injected into the Next.js container at deployment time.
#-------------------------------------------------------------------------
output "aad_authority" {
  description = "OIDC authority URL exposed through the UI runtime configuration."
  value       = module.entra_external_id.authority
}

output "aad_client_id" {
  description = "Client ID of the browser application registration."
  value       = module.entra_external_id.spa_client_id
}

output "aad_tenant_id" {
  description = "External ID tenant ID used by the Azure authentication adapter."
  value       = module.entra_external_id.tenant_id
}

output "aad_api_scope" {
  description = "Fully qualified API scope URI exposed through the UI runtime configuration."
  value       = module.entra_external_id.api_scope_uri
}

#-------------------------------------------------------------------------
# Application Insights — injected into server containers at deployment time.
#-------------------------------------------------------------------------
output "application_insights_connection_string" {
  description = "Application Insights connection string used by Azure telemetry adapters."
  value       = module.observability.application_insights_connection_string
  sensitive   = true
}

#-------------------------------------------------------------------------
# Cloud-neutral deployment contract. Provider-specific outputs above remain
# available to operational scripts; these aliases are consumed by shared
# orchestration and the Next.js runtime configuration.
#-------------------------------------------------------------------------
output "application_url" {
  description = "Public UI origin for the Azure implementation."
  value       = try(module.container_apps.ui_url, local.ui_url)
}

output "ui_app_name" {
  description = "Container App name for the standalone Next.js UI."
  value       = try(module.container_apps.ui_app_name, null)
}

output "container_registry" {
  description = "Container registry endpoint for cloud-neutral build tooling."
  value       = module.acr.login_server
}

output "migration_workload" {
  description = "Provider-native identifier of the one-off migration workload."
  value       = try(module.container_apps.migrations_job_name, null)
}

output "auth_authority" {
  description = "Normalized OIDC authority selected at Azure deployment time."
  value       = module.entra_external_id.authority
}

output "auth_client_id" {
  description = "Normalized public OAuth client ID selected at Azure deployment time."
  value       = module.entra_external_id.spa_client_id
}

output "auth_api_scope" {
  description = "Normalized delegated API scope selected at Azure deployment time."
  value       = module.entra_external_id.api_scope_uri
}
