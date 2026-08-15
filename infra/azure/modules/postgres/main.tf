resource "azurerm_postgresql_flexible_server" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  version             = var.postgres_version

  administrator_login    = var.administrator_login
  administrator_password = var.administrator_password

  sku_name   = var.sku_name
  storage_mb = var.storage_mb

  # Public access, firewall restricted to Azure services + (optionally) the developer.
  public_network_access_enabled = true
  zone                          = "1"

  # No HA / no backup redundancy in dev to save cost.
  backup_retention_days = 7

  tags = var.tags

  lifecycle {
    # Storage auto-grow can bump storage_mb — ignore to avoid drift.
    ignore_changes = [zone, high_availability]
  }
}

resource "azurerm_postgresql_flexible_server_database" "app" {
  name      = var.database_name
  server_id = azurerm_postgresql_flexible_server.this.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# "Allow Azure services" — start=end=0.0.0.0 is Azure's well-known magic entry.
resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_postgresql_flexible_server.this.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}
