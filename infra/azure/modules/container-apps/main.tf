#-------------------------------------------------------------------------
# RabbitMQ — public image, internal-only ingress, single replica. Exposing
# the management UI (15672) would require a second external HTTP ingress,
# which AzureRM 4.68 does not surface (`additional_port_mappings` is not
# in the provider schema at this version). Operators reach the management
# UI via `az containerapp exec` + local port-forward — see
# docs/runbooks/azure-observability.md.
#-------------------------------------------------------------------------
resource "azurerm_container_app" "rabbitmq" {
  name                         = "${var.name_prefix}-rabbitmq"
  container_app_environment_id = var.container_app_environment_id
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
  container_app_environment_id = var.container_app_environment_id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [var.apps_identity_id]
  }

  registry {
    server   = var.acr_login_server
    identity = var.apps_identity_id
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
        name  = "OTEL_SERVICE_NAME"
        value = "ea-api"
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
      # Entra External ID values implement the normalized authentication
      # contract. These identifiers are public, not secrets.
      #---------------------------------------------------------------
      env {
        name  = "Authentication__Enabled"
        value = "true"
      }
      env {
        name  = "Authentication__Provider"
        value = "entra"
      }
      env {
        name  = "Authentication__AllowDev"
        value = tostring(var.allow_dev_auth)
      }
      env {
        name  = "Authentication__AllowGuest"
        value = tostring(var.allow_guest_auth)
      }
      env {
        name  = "Authentication__Authority"
        value = var.aad_authority
      }
      env {
        name  = "Authentication__Audience"
        value = var.aad_audience
      }
      env {
        name  = "Authentication__ClientId"
        value = var.aad_client_id
      }
      env {
        name  = "Authentication__RequiredScope"
        value = "access_as_user"
      }
      env {
        name  = "Observability__Exporter"
        value = "azuremonitor"
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
    azurerm_container_app.rabbitmq,
  ]
}

#-------------------------------------------------------------------------
# UI — the same standalone Next.js server image used on AWS. Runtime
# configuration is injected as environment variables, so promotion between
# clouds and environments never requires rebuilding the browser bundle.
#-------------------------------------------------------------------------
resource "azurerm_container_app" "ui" {
  name                         = "${var.name_prefix}-ui"
  container_app_environment_id = var.container_app_environment_id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [var.apps_identity_id]
  }

  registry {
    server   = var.acr_login_server
    identity = var.apps_identity_id
  }

  template {
    min_replicas = 1
    max_replicas = 3

    container {
      name   = "ui"
      image  = var.ui_image
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "PORT"
        value = tostring(var.ui_target_port)
      }
      env {
        name  = "HOSTNAME"
        value = "0.0.0.0"
      }
      env {
        name  = "DEPLOYMENT_TARGET"
        value = "azure"
      }
      env {
        name  = "API_URL"
        value = "https://${azurerm_container_app.api.ingress[0].fqdn}"
      }
      env {
        name  = "AUTH_PROVIDER"
        value = "entra"
      }
      env {
        name  = "AUTH_AUTHORITY"
        value = var.ui_auth_authority
      }
      env {
        name  = "AUTH_CLIENT_ID"
        value = var.ui_auth_client_id
      }
      env {
        name  = "AUTH_API_SCOPE"
        value = var.ui_auth_api_scope
      }
      env {
        name  = "AUTH_LOGOUT_ENDPOINT"
        value = ""
      }
      env {
        name  = "ENABLE_DEV_AUTH"
        value = tostring(var.allow_dev_auth)
      }
      env {
        name  = "ENABLE_GUEST_AUTH"
        value = tostring(var.allow_guest_auth)
      }
      env {
        name  = "OTEL_SERVICE_NAME"
        value = "ea-ui"
      }

      liveness_probe {
        transport = "HTTP"
        port      = var.ui_target_port
        path      = "/api/health"

        initial_delay           = 10
        interval_seconds        = 30
        timeout                 = 5
        failure_count_threshold = 3
      }

      readiness_probe {
        transport = "HTTP"
        port      = var.ui_target_port
        path      = "/api/health"

        interval_seconds        = 15
        timeout                 = 5
        failure_count_threshold = 3
      }
    }
  }

  ingress {
    external_enabled           = true
    target_port                = var.ui_target_port
    transport                  = "auto"
    allow_insecure_connections = false

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  tags = var.tags
}

#-------------------------------------------------------------------------
# Data engine — no ingress, ACR image, connects to RabbitMQ internally.
#-------------------------------------------------------------------------
resource "azurerm_container_app" "data_engine" {
  name                         = "${var.name_prefix}-data-engine"
  container_app_environment_id = var.container_app_environment_id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [var.apps_identity_id]
  }

  registry {
    server   = var.acr_login_server
    identity = var.apps_identity_id
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
        name  = "OBSERVABILITY_EXPORTER"
        value = "azuremonitor"
      }
      env {
        name        = "APPLICATIONINSIGHTS_CONNECTION_STRING"
        secret_name = "appinsights-connection-string"
      }
      env {
        name  = "OTEL_SERVICE_NAME"
        value = "ea-data-engine"
      }
      env {
        name  = "OTEL_TRACES_SAMPLER"
        value = "parentbased_traceidratio"
      }
      env {
        name  = "OTEL_TRACES_SAMPLER_ARG"
        value = "0.2"
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
    azurerm_container_app.rabbitmq,
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
  container_app_environment_id = var.container_app_environment_id
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
    identity_ids = [var.apps_identity_id]
  }

  registry {
    server   = var.acr_login_server
    identity = var.apps_identity_id
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
    azurerm_container_app.rabbitmq,
  ]
}
