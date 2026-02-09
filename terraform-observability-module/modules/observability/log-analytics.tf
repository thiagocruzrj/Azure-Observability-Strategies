# =============================================================================
# Log Analytics Workspace - 1 per location
# =============================================================================

resource "azurerm_log_analytics_workspace" "main" {
  name                       = "law-${local.name_prefix}"
  location                   = local.resource_group_location
  resource_group_name        = local.resource_group_name
  sku                        = var.log_analytics_sku
  retention_in_days          = var.log_analytics_retention_days
  daily_quota_gb             = var.log_analytics_daily_quota_gb > 0 ? var.log_analytics_daily_quota_gb : -1
  internet_ingestion_enabled = true
  internet_query_enabled     = true

  tags = merge(local.common_tags, {
    ResourceType = "Log Analytics Workspace"
    Purpose      = "Centralized logging and monitoring"
  })

  lifecycle {
    ignore_changes = [tags["DeploymentDate"]]
  }
}

# -----------------------------------------------------------------------------
# Log Analytics Solutions for Application Insights
# -----------------------------------------------------------------------------

resource "azurerm_log_analytics_solution" "application_insights" {
  solution_name         = "ApplicationInsights"
  location              = local.resource_group_location
  resource_group_name   = local.resource_group_name
  workspace_resource_id = azurerm_log_analytics_workspace.main.id
  workspace_name        = azurerm_log_analytics_workspace.main.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ApplicationInsights"
  }

  tags = local.common_tags

  lifecycle {
    ignore_changes = [tags["DeploymentDate"]]
  }
}

# -----------------------------------------------------------------------------
# Diagnostic Settings for Log Analytics Workspace itself
# -----------------------------------------------------------------------------

resource "azurerm_monitor_diagnostic_setting" "law" {
  name                       = "diag-law-${local.name_prefix}"
  target_resource_id         = azurerm_log_analytics_workspace.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "Audit"
  }

  enabled_log {
    category = "SummaryLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
