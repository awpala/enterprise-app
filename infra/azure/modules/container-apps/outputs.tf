output "environment_id" {
  description = "Container Apps Environment resource ID."
  value       = var.container_app_environment_id
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

output "ui_url" {
  description = "Public HTTPS URL of the Next.js Container App."
  value       = "https://${azurerm_container_app.ui.ingress[0].fqdn}"
}

output "ui_app_name" {
  description = "Name of the Next.js UI Container App."
  value       = azurerm_container_app.ui.name
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
