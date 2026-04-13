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

output "swa_name" {
  description = "Static Web App name. Use with: az staticwebapp secrets list --name <this>"
  value       = module.swa.name
}

output "swa_url" {
  description = "Public HTTPS URL of the Static Web App."
  value       = module.swa.url
}

output "swa_deployment_token" {
  description = "SWA deployment token. Use with: swa deploy <dist> --deployment-token <this> --env production"
  value       = module.swa.api_key
  sensitive   = true
}

#-------------------------------------------------------------------------
# Entra External ID — consumed by .github/scripts/build-ui.sh to bake
# the MSAL config into the SPA bundle at build time.
#-------------------------------------------------------------------------
output "aad_authority" {
  description = "OIDC authority URL (AAD_AUTHORITY in the SPA build)."
  value       = module.entra_external_id.authority
}

output "aad_client_id" {
  description = "Client ID of the SPA app registration (AAD_CLIENT_ID in the SPA build)."
  value       = module.entra_external_id.spa_client_id
}

output "aad_tenant_id" {
  description = "External ID tenant ID (AAD_TENANT_ID in the SPA build)."
  value       = module.entra_external_id.tenant_id
}

output "aad_api_scope" {
  description = "Fully-qualified API scope URI (AAD_API_SCOPE in the SPA build, passed to msal.loginRedirect)."
  value       = module.entra_external_id.api_scope_uri
}
