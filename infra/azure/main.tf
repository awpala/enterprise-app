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
# Shared Container Apps platform. Keeping the environment and pull identity
# at the root lets the Entra registration use the deterministic UI FQDN
# before the application resources themselves are created.
#-------------------------------------------------------------------------
resource "azurerm_container_app_environment" "this" {
  name                       = "${local.name_prefix}-cae"
  resource_group_name        = azurerm_resource_group.this.name
  location                   = azurerm_resource_group.this.location
  log_analytics_workspace_id = module.observability.log_analytics_workspace_id
  tags                       = local.common_tags
}

resource "azurerm_user_assigned_identity" "apps" {
  name                = "${local.name_prefix}-apps-mi"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = local.common_tags
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = module.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.apps.principal_id
}

moved {
  from = module.container_apps.azurerm_container_app_environment.this
  to   = azurerm_container_app_environment.this
}

moved {
  from = module.container_apps.azurerm_user_assigned_identity.apps
  to   = azurerm_user_assigned_identity.apps
}

moved {
  from = module.container_apps.azurerm_role_assignment.acr_pull
  to   = azurerm_role_assignment.acr_pull
}

locals {
  ui_url = "https://${local.name_prefix}-ui.${azurerm_container_app_environment.this.default_domain}"
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
  application_url    = local.ui_url
  external_tenant_id = var.external_tenant_id
  tenant_subdomain   = var.tenant_subdomain
}

#-------------------------------------------------------------------------
# Container Apps (API, data-engine, RabbitMQ, migrations job)
#-------------------------------------------------------------------------
locals {
  api_image         = "${module.acr.login_server}/ea-api:${var.image_tag}"
  data_engine_image = "${module.acr.login_server}/ea-data-engine:${var.image_tag}"
  migrations_image  = "${module.acr.login_server}/ea-migrations:${var.image_tag}"
  ui_image          = "${module.acr.login_server}/ea-ui:${var.image_tag}"
}

module "container_apps" {
  source = "./modules/container-apps"

  name_prefix                  = local.name_prefix
  resource_group_name          = azurerm_resource_group.this.name
  location                     = azurerm_resource_group.this.location
  container_app_environment_id = azurerm_container_app_environment.this.id
  apps_identity_id             = azurerm_user_assigned_identity.apps.id

  acr_login_server = module.acr.login_server

  api_image         = local.api_image
  data_engine_image = local.data_engine_image
  migrations_image  = local.migrations_image
  ui_image          = local.ui_image
  api_target_port   = var.api_target_port
  ui_target_port    = 3000

  postgres_connection_string   = module.postgres.connection_string
  migrations_connection_string = module.postgres.connection_string

  rabbitmq_username = var.rabbitmq_username
  rabbitmq_password = random_password.rabbitmq.result

  application_insights_connection_string = module.observability.application_insights_connection_string

  api_allowed_origins = [local.ui_url]

  # Entra External ID wiring — plain envvars on the API container
  # (tenantId / clientId / authority / audience are not secrets).
  aad_authority = module.entra_external_id.authority
  aad_audience  = module.entra_external_id.api_audience
  aad_client_id = module.entra_external_id.api_client_id

  ui_auth_authority = module.entra_external_id.authority
  ui_auth_client_id = module.entra_external_id.spa_client_id
  ui_auth_api_scope = module.entra_external_id.api_scope_uri

  # Deployed-dev synthetic session (JwtOrDev policy scheme in the API).
  # True in dev, false in prod; see variables.tf for rationale.
  allow_dev_auth = var.allow_dev_auth

  # Prod-only guest-mode failsafe (synthetic sentinel principal in the API).
  # False everywhere except prod; see variables.tf for rationale.
  allow_guest_auth = var.allow_guest_auth

  tags = local.common_tags

  depends_on = [azurerm_role_assignment.acr_pull]
}

#-------------------------------------------------------------------------
# Platform diagnostic settings — Postgres / ACR logs + metrics → LAW.
# Container App Environment logs are already routed via module.container_apps.
#-------------------------------------------------------------------------
module "diagnostics" {
  source = "./modules/diagnostics"

  log_analytics_workspace_id = module.observability.log_analytics_workspace_id
  postgres_server_id         = module.postgres.id
  container_registry_id      = module.acr.id
}
