output "id" {
  description = "Flexible Server resource ID."
  value       = azurerm_postgresql_flexible_server.this.id
}

output "fqdn" {
  description = "Fully-qualified DNS name of the server."
  value       = azurerm_postgresql_flexible_server.this.fqdn
}

output "database_name" {
  description = "Application database name."
  value       = azurerm_postgresql_flexible_server_database.app.name
}

output "administrator_login" {
  description = "Admin login name."
  value       = azurerm_postgresql_flexible_server.this.administrator_login
}

output "connection_string" {
  description = "Npgsql connection string for EA.Api (ConnectionStrings__DefaultConnection)."
  value       = "Host=${azurerm_postgresql_flexible_server.this.fqdn};Port=5432;Database=${azurerm_postgresql_flexible_server_database.app.name};Username=${azurerm_postgresql_flexible_server.this.administrator_login};Password=${var.administrator_password};SSL Mode=Require;Trust Server Certificate=true"
  sensitive   = true
}
