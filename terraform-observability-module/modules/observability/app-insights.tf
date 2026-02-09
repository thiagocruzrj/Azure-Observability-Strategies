# =============================================================================
# Application Insights - 1 per application (Workspace-based)
# =============================================================================

resource "azurerm_application_insights" "apps" {
  for_each = var.applications

  name                = "ai-${var.project_name}-${each.key}-${var.environment}-${local.loc_short}"
  location            = local.resource_group_location
  resource_group_name = local.resource_group_name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"

  # Data retention and sampling
  retention_in_days = var.app_insights_retention_days
  daily_data_cap_in_gb = var.app_insights_daily_cap_gb
  daily_data_cap_notifications_disabled = false
  sampling_percentage = var.app_insights_sampling_percentage

  # Disable local authentication for security (use managed identity)
  local_authentication_disabled = false
  internet_ingestion_enabled    = true
  internet_query_enabled        = true

  tags = merge(local.common_tags, {
    ResourceType = "Application Insights"
    Application  = each.key
    AppType      = each.value.type
  })

  lifecycle {
    ignore_changes = [tags["DeploymentDate"]]
  }
}

# -----------------------------------------------------------------------------
# Smart Detection Rules Configuration
# -----------------------------------------------------------------------------

resource "azurerm_application_insights_smart_detection_rule" "slow_response" {
  for_each = var.applications

  name                    = "Slow server response time"
  application_insights_id = azurerm_application_insights.apps[each.key].id
  enabled                 = true
  send_emails_to_subscription_owners = true
  additional_email_recipients        = var.alert_email_recipients
}

resource "azurerm_application_insights_smart_detection_rule" "degradation" {
  for_each = var.applications

  name                    = "Degradation in server response time"
  application_insights_id = azurerm_application_insights.apps[each.key].id
  enabled                 = true
  send_emails_to_subscription_owners = true
  additional_email_recipients        = var.alert_email_recipients
}

resource "azurerm_application_insights_smart_detection_rule" "failure_anomalies" {
  for_each = var.applications

  name                    = "Slow page load time"
  application_insights_id = azurerm_application_insights.apps[each.key].id
  enabled                 = true
  send_emails_to_subscription_owners = true
  additional_email_recipients        = var.alert_email_recipients
}
