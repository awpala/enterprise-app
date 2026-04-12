resource "azurerm_key_vault" "this" {
  name                       = var.name
  resource_group_name        = var.resource_group_name
  location                   = var.location
  tenant_id                  = var.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  # RBAC mode — cleaner than access policies; uses role assignments below.
  rbac_authorization_enabled = true

  # Allow Azure services (Container Apps) + public for dev. Tighten later.
  public_network_access_enabled = true

  network_acls {
    bypass         = "AzureServices"
    default_action = "Allow"
  }

  tags = var.tags
}

# Terraform's identity needs write access to seed secrets.
resource "azurerm_role_assignment" "deployer_officer" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.deployer_object_id
}

# Container App managed identities need read access.
resource "azurerm_role_assignment" "readers" {
  for_each             = toset(var.reader_object_ids)
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = each.value
}
