#-------------------------------------------------------------------------
# Identity of the caller (az login user). Used for Key Vault RBAC.
#-------------------------------------------------------------------------
data "azurerm_client_config" "current" {}

#-------------------------------------------------------------------------
# Resource Group
#-------------------------------------------------------------------------
resource "azurerm_resource_group" "this" {
  name     = "${local.name_prefix}-rg"
  location = var.location
  tags     = local.common_tags
}

#-------------------------------------------------------------------------
# Container Registry
#
# NOTE: ACR must exist before Container Apps can reference images. The
# first-pass `terraform apply` is -targeted at this module; then images
# are built via `az acr build`; then a full apply wires up Container Apps.
# See infra/README.md.
#-------------------------------------------------------------------------
module "acr" {
  source = "./modules/container-registry"

  # ACR names must be 5-50 alphanumerics (no hyphens), globally unique.
  name                = "${var.project}${var.environment}acr${var.name_suffix}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = "Basic"
  tags                = local.common_tags
}

#-------------------------------------------------------------------------
# Observability: Log Analytics + App Insights
#-------------------------------------------------------------------------
module "observability" {
  source = "./modules/observability"

  name_prefix         = local.name_prefix
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = local.common_tags
}

#-------------------------------------------------------------------------
# Secrets: generate DB and RabbitMQ passwords, store in Key Vault.
#-------------------------------------------------------------------------
resource "random_password" "postgres" {
  length      = 24
  special     = true
  min_lower   = 2
  min_upper   = 2
  min_numeric = 2
  min_special = 2
  # Avoid chars that upset connection strings / shells.
  override_special = "!@#%*-_=+?"
}

resource "random_password" "rabbitmq" {
  length           = 24
  special          = true
  override_special = "!@#%*-_=+?"
}

module "key_vault" {
  source = "./modules/key-vault"

  # KV names must be 3-24 alphanumerics + hyphens, globally unique.
  name                = "${var.project}-${var.environment}-kv-${var.name_suffix}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  deployer_object_id  = data.azurerm_client_config.current.object_id
  reader_object_ids   = []
  tags                = local.common_tags
}

resource "azurerm_key_vault_secret" "postgres_password" {
  name         = "postgres-admin-password"
  value        = random_password.postgres.result
  key_vault_id = module.key_vault.id

  depends_on = [module.key_vault]
}

resource "azurerm_key_vault_secret" "rabbitmq_password" {
  name         = "rabbitmq-password"
  value        = random_password.rabbitmq.result
  key_vault_id = module.key_vault.id

  depends_on = [module.key_vault]
}

#-------------------------------------------------------------------------
# Postgres Flexible Server
#
# Postgres Flexible Server is not offered on every subscription in every
# region (basic/personal subs hit `LocationIsOfferRestricted` in eastus);
# pin to eastus2 regardless of var.location to keep this deployable. The
# RG stays in var.location — Azure allows cross-region resources in a
# single RG, and cross-US latency is fine for an MVP.
#-------------------------------------------------------------------------
module "postgres" {
  source = "./modules/postgres"

  name                   = "${local.name_prefix}-pgsql-${var.name_suffix}"
  resource_group_name    = azurerm_resource_group.this.name
  location               = "eastus2"
  administrator_login    = var.postgres_admin_username
  administrator_password = random_password.postgres.result
  database_name          = var.postgres_database_name
  tags                   = local.common_tags
}

#-------------------------------------------------------------------------
# Static Web App for the Angular UI
#
# SWA is GA only in a subset of regions; pin to eastus2 regardless of
# var.location to keep this deployable everywhere.
#
# Declared before container_apps because the SPA redirect URI depends on
# module.swa.url via module.entra_external_id.
#-------------------------------------------------------------------------
module "swa" {
  source = "./modules/static-web-app"

  name                = "${local.name_prefix}-swa-${var.name_suffix}"
  resource_group_name = azurerm_resource_group.this.name
  location            = "eastus2"
  sku_tier            = "Free"
  tags                = local.common_tags
}

#-------------------------------------------------------------------------
# Entra External ID (CIAM) — customer SSO app registrations, user flow,
# and identity providers. All resources live in the External ID tenant
# (not the workforce tenant), so this module is pinned to the `.external`
# aliased azuread provider.
#-------------------------------------------------------------------------
module "entra_external_id" {
  source = "./modules/entra-external-id"

  providers = {
    azuread = azuread.external
  }

  environment        = var.environment
  swa_url            = module.swa.url
  external_tenant_id = var.external_tenant_id
  tenant_subdomain   = var.tenant_subdomain
  tags               = local.common_tags
}

#-------------------------------------------------------------------------
# Container Apps (API, data-engine, RabbitMQ, migrations job)
#-------------------------------------------------------------------------
locals {
  api_image         = "${module.acr.login_server}/ea-api:${var.image_tag}"
  data_engine_image = "${module.acr.login_server}/ea-data-engine:${var.image_tag}"
  migrations_image  = "${module.acr.login_server}/ea-migrations:${var.image_tag}"
}

module "container_apps" {
  source = "./modules/container-apps"

  name_prefix                = local.name_prefix
  resource_group_name        = azurerm_resource_group.this.name
  location                   = azurerm_resource_group.this.location
  log_analytics_workspace_id = module.observability.log_analytics_workspace_id

  acr_id           = module.acr.id
  acr_login_server = module.acr.login_server

  api_image         = local.api_image
  data_engine_image = local.data_engine_image
  migrations_image  = local.migrations_image
  api_target_port   = var.api_target_port

  postgres_connection_string   = module.postgres.connection_string
  migrations_connection_string = module.postgres.connection_string

  rabbitmq_username = var.rabbitmq_username
  rabbitmq_password = random_password.rabbitmq.result

  application_insights_connection_string = module.observability.application_insights_connection_string

  api_allowed_origins = [module.swa.url]

  # Entra External ID wiring — plain envvars on the API container
  # (tenantId / clientId / authority / audience are not secrets).
  aad_authority = module.entra_external_id.authority
  aad_audience  = module.entra_external_id.api_audience
  aad_client_id = module.entra_external_id.api_client_id
  aad_tenant_id = module.entra_external_id.tenant_id

  tags = local.common_tags
}
