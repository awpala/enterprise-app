output "id" {
  description = "Static Web App resource ID."
  value       = azurerm_static_web_app.this.id
}

output "name" {
  description = "Static Web App name."
  value       = azurerm_static_web_app.this.name
}

output "default_host_name" {
  description = "Default hostname assigned by Azure (e.g. polite-tree-123.azurestaticapps.net)."
  value       = azurerm_static_web_app.this.default_host_name
}

output "url" {
  description = "Public HTTPS URL of the SWA."
  value       = "https://${azurerm_static_web_app.this.default_host_name}"
}

output "api_key" {
  description = "Deployment API key — use with `swa deploy --deployment-token <key>`."
  value       = azurerm_static_web_app.this.api_key
  sensitive   = true
}
