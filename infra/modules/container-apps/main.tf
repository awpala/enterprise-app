#-------------------------------------------------------------------------
# Container Apps Environment
#-------------------------------------------------------------------------
resource "azurerm_container_app_environment" "this" {
  name                       = "${var.name_prefix}-cae"
  resource_group_name        = var.resource_group_name
  location                   = var.location
  log_analytics_workspace_id = var.log_analytics_workspace_id

  tags = var.tags
}

#-------------------------------------------------------------------------
# User-assigned managed identity shared by all Container Apps for ACR pull
# and (optionally) Key Vault reads. Using one shared identity keeps the
# module simple for MVP; split per-app later if needed.
#-------------------------------------------------------------------------
resource "azurerm_user_assigned_identity" "apps" {
  name                = "${var.name_prefix}-apps-mi"
  resource_group_name = var.resource_group_name
  location            = var.location

  tags = var.tags
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.apps.principal_id
}

#-------------------------------------------------------------------------
# RabbitMQ — public image, internal-only ingress, single replica.
#-------------------------------------------------------------------------
resource "azurerm_container_app" "rabbitmq" {
  name                         = "${var.name_prefix}-rabbitmq"
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "rabbitmq"
      image  = "rabbitmq:4-management"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "RABBITMQ_DEFAULT_USER"
        value = var.rabbitmq_username
      }
      env {
        name        = "RABBITMQ_DEFAULT_PASS"
        secret_name = "rabbitmq-password"
      }
    }
  }

  secret {
    name  = "rabbitmq-password"
    value = var.rabbitmq_password
  }

  ingress {
    external_enabled = false
    target_port      = 5672
    exposed_port     = 5672
    transport        = "tcp"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  tags = var.tags
}

#-------------------------------------------------------------------------
# API — external ingress, ACR image, env bound to secrets.
#-------------------------------------------------------------------------
resource "azurerm_container_app" "api" {
  name                         = "${var.name_prefix}-api"
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.apps.id]
  }

  registry {
    server   = var.acr_login_server
    identity = azurerm_user_assigned_identity.apps.id
  }

  template {
    min_replicas = 1
    max_replicas = 3

    container {
      name   = "api"
      image  = var.api_image
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "ASPNETCORE_ENVIRONMENT"
        value = "Production"
      }
      env {
        name  = "ASPNETCORE_URLS"
        value = "http://+:${var.api_target_port}"
      }
      env {
        name        = "ConnectionStrings__DefaultConnection"
        secret_name = "postgres-connection-string"
      }
      env {
        name  = "RabbitMQ__Host"
        value = azurerm_container_app.rabbitmq.name
      }
      env {
        name  = "RabbitMQ__Username"
        value = var.rabbitmq_username
      }
      env {
        name        = "RabbitMQ__Password"
        secret_name = "rabbitmq-password"
      }
      env {
        name        = "APPLICATIONINSIGHTS_CONNECTION_STRING"
        secret_name = "appinsights-connection-string"
      }
      env {
        name  = "Seeding__Enabled"
        value = "true"
      }
      env {
        name  = "Seeding__SeedPath"
        value = "/app/seed"
      }

      #---------------------------------------------------------------
      # Entra External ID (AzureAd:* config section consumed by
      # Microsoft.Identity.Web). Plain envvars — these are public
      # identifiers, not secrets.
      #---------------------------------------------------------------
      env {
        name  = "AzureAd__Enabled"
        value = "true"
      }
      env {
        name  = "AzureAd__AllowGuest"
        value = tostring(var.allow_guest_auth)
      }
      env {
        name  = "AzureAd__Authority"
        value = var.aad_authority
      }
      env {
        name  = "AzureAd__Audience"
        value = var.aad_audience
      }
      env {
        name  = "AzureAd__ClientId"
        value = var.aad_client_id
      }
      env {
        name  = "AzureAd__TenantId"
        value = var.aad_tenant_id
      }

      dynamic "env" {
        for_each = { for i, v in var.api_allowed_origins : tostring(i) => v }
        content {
          name  = "Cors__AllowedOrigins__${env.key}"
          value = env.value
        }
      }

      liveness_probe {
        transport = "HTTP"
        port      = var.api_target_port
        path      = "/health/live"

        initial_delay           = 10
        interval_seconds        = 30
        timeout                 = 5
        failure_count_threshold = 3
      }

      readiness_probe {
        transport = "HTTP"
        port      = var.api_target_port
        path      = "/health/ready"

        interval_seconds        = 15
        timeout                 = 5
        failure_count_threshold = 3
      }

      startup_probe {
        transport = "HTTP"
        port      = var.api_target_port
        path      = "/health/startup"

        interval_seconds        = 10
        timeout                 = 5
        failure_count_threshold = 30
      }
    }
  }

  secret {
    name  = "postgres-connection-string"
    value = var.postgres_connection_string
  }
  secret {
    name  = "rabbitmq-password"
    value = var.rabbitmq_password
  }
  secret {
    name  = "appinsights-connection-string"
    value = var.application_insights_connection_string
  }

  ingress {
    external_enabled           = true
    target_port                = var.api_target_port
    transport                  = "auto"
    allow_insecure_connections = false

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  tags = var.tags

  depends_on = [
    azurerm_role_assignment.acr_pull,
  ]
}

#-------------------------------------------------------------------------
# Data engine — no ingress, ACR image, connects to RabbitMQ internally.
#-------------------------------------------------------------------------
resource "azurerm_container_app" "data_engine" {
  name                         = "${var.name_prefix}-data-engine"
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.apps.id]
  }

  registry {
    server   = var.acr_login_server
    identity = azurerm_user_assigned_identity.apps.id
  }

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "data-engine"
      image  = var.data_engine_image
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "RABBITMQ_HOST"
        value = azurerm_container_app.rabbitmq.name
      }
      env {
        name  = "RABBITMQ_PORT"
        value = "5672"
      }
      env {
        name  = "RABBITMQ_USER"
        value = var.rabbitmq_username
      }
      env {
        name        = "RABBITMQ_PASSWORD"
        secret_name = "rabbitmq-password"
      }
      env {
        name  = "LOG_LEVEL"
        value = "INFO"
      }
      env {
        name        = "APPLICATIONINSIGHTS_CONNECTION_STRING"
        secret_name = "appinsights-connection-string"
      }
    }
  }

  secret {
    name  = "rabbitmq-password"
    value = var.rabbitmq_password
  }
  secret {
    name  = "appinsights-connection-string"
    value = var.application_insights_connection_string
  }

  tags = var.tags

  depends_on = [
    azurerm_role_assignment.acr_pull,
  ]
}

#-------------------------------------------------------------------------
# Migrations — Container Apps Job, manual trigger, run on demand.
#
# The EF Core migration bundle boots the API host first, so the connection
# string must be resolvable via configuration before the bundle runs. We
# inject it under the same key the API uses (ConnectionStrings__DefaultConnection).
#-------------------------------------------------------------------------
resource "azurerm_container_app_job" "migrations" {
  name                         = "${var.name_prefix}-migrations"
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = var.resource_group_name
  location                     = var.location

  replica_timeout_in_seconds = 600
  replica_retry_limit        = 1

  manual_trigger_config {
    parallelism              = 1
    replica_completion_count = 1
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.apps.id]
  }

  registry {
    server   = var.acr_login_server
    identity = azurerm_user_assigned_identity.apps.id
  }

  template {
    container {
      name   = "migrations"
      image  = var.migrations_image
      cpu    = 0.5
      memory = "1Gi"

      env {
        name        = "ConnectionStrings__DefaultConnection"
        secret_name = "postgres-connection-string"
      }
    }
  }

  secret {
    name  = "postgres-connection-string"
    value = var.migrations_connection_string
  }

  tags = var.tags

  depends_on = [
    azurerm_role_assignment.acr_pull,
  ]
}
