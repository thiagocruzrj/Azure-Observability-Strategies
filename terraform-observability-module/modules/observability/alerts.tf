# =============================================================================
# Action Groups and Metric Alerts
# =============================================================================

# -----------------------------------------------------------------------------
# Action Group for Alert Notifications
# -----------------------------------------------------------------------------

resource "azurerm_monitor_action_group" "main" {
  count = var.enable_alerts ? 1 : 0

  name                = "ag-${local.name_prefix}"
  resource_group_name = local.resource_group_name
  short_name          = substr(replace("${var.project_name}${var.environment}", "-", ""), 0, 12)

  dynamic "email_receiver" {
    for_each = var.alert_email_recipients
    content {
      name                    = "email-${email_receiver.key}"
      email_address           = email_receiver.value
      use_common_alert_schema = true
    }
  }

  dynamic "webhook_receiver" {
    for_each = var.alert_webhook_url != null ? [1] : []
    content {
      name                    = "webhook-alerts"
      service_uri             = var.alert_webhook_url
      use_common_alert_schema = true
    }
  }

  tags = merge(local.common_tags, {
    ResourceType = "Action Group"
    Purpose      = "Alert notifications"
  })

  lifecycle {
    ignore_changes = [tags["DeploymentDate"]]
  }
}

# -----------------------------------------------------------------------------
# CPU Percentage Alerts
# -----------------------------------------------------------------------------

resource "azurerm_monitor_metric_alert" "cpu_web" {
  for_each = var.enable_alerts ? local.web_apps : {}

  name                = "alert-cpu-${each.key}-${var.environment}"
  resource_group_name = local.resource_group_name
  scopes              = [azurerm_windows_web_app.web[each.key].id]
  description         = "Alert when CPU percentage exceeds ${local.thresholds.cpu_percentage}% for ${each.key}"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "CpuPercentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = local.thresholds.cpu_percentage
  }

  action {
    action_group_id = azurerm_monitor_action_group.main[0].id
  }

  tags = merge(local.common_tags, {
    ResourceType = "Metric Alert"
    AlertType    = "CPU"
    Application  = each.key
  })

  lifecycle {
    ignore_changes = [tags["DeploymentDate"]]
  }
}

resource "azurerm_monitor_metric_alert" "cpu_api" {
  for_each = var.enable_alerts ? local.api_apps : {}

  name                = "alert-cpu-${each.key}-${var.environment}"
  resource_group_name = local.resource_group_name
  scopes              = [azurerm_windows_web_app.api[each.key].id]
  description         = "Alert when CPU percentage exceeds ${local.thresholds.cpu_percentage}% for ${each.key}"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "CpuPercentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = local.thresholds.cpu_percentage
  }

  action {
    action_group_id = azurerm_monitor_action_group.main[0].id
  }

  tags = local.common_tags

  lifecycle {
    ignore_changes = [tags["DeploymentDate"]]
  }
}

# -----------------------------------------------------------------------------
# Memory Percentage Alerts
# -----------------------------------------------------------------------------

resource "azurerm_monitor_metric_alert" "memory_web" {
  for_each = var.enable_alerts ? local.web_apps : {}

  name                = "alert-memory-${each.key}-${var.environment}"
  resource_group_name = local.resource_group_name
  scopes              = [azurerm_windows_web_app.web[each.key].id]
  description         = "Alert when memory percentage exceeds ${local.thresholds.memory_percentage}% for ${each.key}"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "MemoryPercentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = local.thresholds.memory_percentage
  }

  action {
    action_group_id = azurerm_monitor_action_group.main[0].id
  }

  tags = local.common_tags

  lifecycle {
    ignore_changes = [tags["DeploymentDate"]]
  }
}

resource "azurerm_monitor_metric_alert" "memory_api" {
  for_each = var.enable_alerts ? local.api_apps : {}

  name                = "alert-memory-${each.key}-${var.environment}"
  resource_group_name = local.resource_group_name
  scopes              = [azurerm_windows_web_app.api[each.key].id]
  description         = "Alert when memory percentage exceeds ${local.thresholds.memory_percentage}% for ${each.key}"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "MemoryPercentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = local.thresholds.memory_percentage
  }

  action {
    action_group_id = azurerm_monitor_action_group.main[0].id
  }

  tags = local.common_tags

  lifecycle {
    ignore_changes = [tags["DeploymentDate"]]
  }
}

# -----------------------------------------------------------------------------
# HTTP 5xx Error Alerts
# -----------------------------------------------------------------------------

resource "azurerm_monitor_metric_alert" "http5xx_web" {
  for_each = var.enable_alerts ? local.web_apps : {}

  name                = "alert-http5xx-${each.key}-${var.environment}"
  resource_group_name = local.resource_group_name
  scopes              = [azurerm_windows_web_app.web[each.key].id]
  description         = "Alert when HTTP 5xx errors exceed ${local.thresholds.http_5xx_count} for ${each.key}"
  severity            = 1
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "Http5xx"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = local.thresholds.http_5xx_count
  }

  action {
    action_group_id = azurerm_monitor_action_group.main[0].id
  }

  tags = local.common_tags

  lifecycle {
    ignore_changes = [tags["DeploymentDate"]]
  }
}

resource "azurerm_monitor_metric_alert" "http5xx_api" {
  for_each = var.enable_alerts ? local.api_apps : {}

  name                = "alert-http5xx-${each.key}-${var.environment}"
  resource_group_name = local.resource_group_name
  scopes              = [azurerm_windows_web_app.api[each.key].id]
  description         = "Alert when HTTP 5xx errors exceed ${local.thresholds.http_5xx_count} for ${each.key}"
  severity            = 1
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "Http5xx"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = local.thresholds.http_5xx_count
  }

  action {
    action_group_id = azurerm_monitor_action_group.main[0].id
  }

  tags = local.common_tags

  lifecycle {
    ignore_changes = [tags["DeploymentDate"]]
  }
}

# -----------------------------------------------------------------------------
# Response Time Alerts
# -----------------------------------------------------------------------------

resource "azurerm_monitor_metric_alert" "response_time_web" {
  for_each = var.enable_alerts ? local.web_apps : {}

  name                = "alert-response-${each.key}-${var.environment}"
  resource_group_name = local.resource_group_name
  scopes              = [azurerm_windows_web_app.web[each.key].id]
  description         = "Alert when average response time exceeds ${local.thresholds.response_time_ms}ms for ${each.key}"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "HttpResponseTime"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = local.thresholds.response_time_ms / 1000 # Convert ms to seconds
  }

  action {
    action_group_id = azurerm_monitor_action_group.main[0].id
  }

  tags = local.common_tags

  lifecycle {
    ignore_changes = [tags["DeploymentDate"]]
  }
}

resource "azurerm_monitor_metric_alert" "response_time_api" {
  for_each = var.enable_alerts ? local.api_apps : {}

  name                = "alert-response-${each.key}-${var.environment}"
  resource_group_name = local.resource_group_name
  scopes              = [azurerm_windows_web_app.api[each.key].id]
  description         = "Alert when average response time exceeds ${local.thresholds.response_time_ms}ms for ${each.key}"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "HttpResponseTime"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = local.thresholds.response_time_ms / 1000 # Convert ms to seconds
  }

  action {
    action_group_id = azurerm_monitor_action_group.main[0].id
  }

  tags = local.common_tags

  lifecycle {
    ignore_changes = [tags["DeploymentDate"]]
  }
}

# -----------------------------------------------------------------------------
# Function App Execution Alerts
# -----------------------------------------------------------------------------

resource "azurerm_monitor_metric_alert" "function_errors" {
  for_each = var.enable_alerts ? local.function_apps : {}

  name                = "alert-func-errors-${each.key}-${var.environment}"
  resource_group_name = local.resource_group_name
  scopes              = [azurerm_windows_function_app.function[each.key].id]
  description         = "Alert when function execution errors exceed threshold for ${each.key}"
  severity            = 1
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "Http5xx"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = local.thresholds.http_5xx_count
  }

  action {
    action_group_id = azurerm_monitor_action_group.main[0].id
  }

  tags = local.common_tags

  lifecycle {
    ignore_changes = [tags["DeploymentDate"]]
  }
}

# -----------------------------------------------------------------------------
# Application Insights Availability Alerts
# -----------------------------------------------------------------------------

resource "azurerm_monitor_metric_alert" "availability" {
  for_each = var.enable_alerts && var.enable_availability_tests ? local.apps_with_endpoints : {}

  name                = "alert-availability-${each.key}-${var.environment}"
  resource_group_name = local.resource_group_name
  scopes              = [azurerm_application_insights.apps[each.key].id]
  description         = "Alert when availability drops below ${local.thresholds.availability_percent}% for ${each.key}"
  severity            = 1
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.Insights/components"
    metric_name      = "availabilityResults/availabilityPercentage"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = local.thresholds.availability_percent
  }

  action {
    action_group_id = azurerm_monitor_action_group.main[0].id
  }

  tags = local.common_tags

  lifecycle {
    ignore_changes = [tags["DeploymentDate"]]
  }
}
