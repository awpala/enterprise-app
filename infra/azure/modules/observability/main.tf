resource "azurerm_log_analytics_workspace" "this" {
  name                = "${var.name_prefix}-law"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_in_days

  tags = var.tags
}

resource "azurerm_application_insights" "this" {
  name                = "${var.name_prefix}-appi"
  resource_group_name = var.resource_group_name
  location            = var.location
  workspace_id        = azurerm_log_analytics_workspace.this.id
  application_type    = "web"

  tags = var.tags
}

#-------------------------------------------------------------------------
# Azure Monitor Workbooks — overview + errors drill-down. Bound to the
# App Insights component above via `source_id`. Names are deterministic
# GUIDs derived from the env-scoped name_prefix so dev and prod don't
# collide if they ever land in the same subscription.
#-------------------------------------------------------------------------
resource "azurerm_application_insights_workbook" "overview" {
  name                = uuidv5("dns", "${var.name_prefix}-overview-workbook")
  resource_group_name = var.resource_group_name
  location            = var.location

  display_name = "${var.name_prefix} — Overview"
  data_json    = file("${path.module}/workbooks/overview.workbook.json")

  source_id = lower(azurerm_application_insights.this.id)

  tags = var.tags
}

resource "azurerm_application_insights_workbook" "errors" {
  name                = uuidv5("dns", "${var.name_prefix}-errors-workbook")
  resource_group_name = var.resource_group_name
  location            = var.location

  display_name = "${var.name_prefix} — Errors"
  data_json    = file("${path.module}/workbooks/errors.workbook.json")

  source_id = lower(azurerm_application_insights.this.id)

  tags = var.tags
}
