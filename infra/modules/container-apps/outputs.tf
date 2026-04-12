output "environment_id" {
  description = "Container Apps Environment resource ID."
  value       = azurerm_container_app_environment.this.id
}

output "apps_identity_principal_id" {
  description = "Principal ID of the user-assigned managed identity shared by all Container Apps."
  value       = azurerm_user_assigned_identity.apps.principal_id
}

output "api_fqdn" {
  description = "Public FQDN of the API Container App."
  value       = azurerm_container_app.api.ingress[0].fqdn
}

output "api_url" {
  description = "Public HTTPS URL of the API."
  value       = "https://${azurerm_container_app.api.ingress[0].fqdn}"
}

output "api_app_name" {
  description = "Name of the API Container App (for az CLI commands)."
  value       = azurerm_container_app.api.name
}

output "data_engine_app_name" {
  description = "Name of the data-engine Container App."
  value       = azurerm_container_app.data_engine.name
}

output "rabbitmq_app_name" {
  description = "Name of the RabbitMQ Container App."
  value       = azurerm_container_app.rabbitmq.name
}

output "migrations_job_name" {
  description = "Name of the migrations Container App Job (use with `az containerapp job start`)."
  value       = azurerm_container_app_job.migrations.name
}
