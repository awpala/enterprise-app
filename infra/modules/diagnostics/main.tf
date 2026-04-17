#-------------------------------------------------------------------------
# Platform diagnostic settings that route Azure-resource-level logs and
# metrics into the shared Log Analytics Workspace. App-level telemetry
# (traces/logs/metrics from the .NET API, Python data-engine, and Angular
# SPA) flows through App Insights via the OpenTelemetry distro; this
# module covers the rest of the stack.
#
# Container App Environment logging is NOT wired here — it is already
# routed to LAW via the `log_analytics_workspace_id` argument on
# azurerm_container_app_environment in modules/container-apps. Adding a
# diagnostic_setting on top would duplicate ingestion.
#
# Postgres Flexible Server: we ship only the always-on log categories
# (PostgreSQLLogs, PostgreSQLFlexSessions). The Query Store categories
# (PostgreSQLFlexQueryStoreRuntime, PostgreSQLFlexQueryStoreWaitStatistics)
# are gated on the `pg_qs.query_capture_mode` server parameter being set
# to TOP or ALL; enable Query Store first, then re-add those categories.
#-------------------------------------------------------------------------

resource "azurerm_monitor_diagnostic_setting" "postgres" {
  name                       = "diag-to-law"
  target_resource_id         = var.postgres_server_id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log { category = "PostgreSQLLogs" }
  enabled_log { category = "PostgreSQLFlexSessions" }

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "swa" {
  name                       = "diag-to-law"
  target_resource_id         = var.static_web_app_id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "acr" {
  name                       = "diag-to-law"
  target_resource_id         = var.container_registry_id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log { category = "ContainerRegistryLoginEvents" }
  enabled_log { category = "ContainerRegistryRepositoryEvents" }

  enabled_metric {
    category = "AllMetrics"
  }
}
