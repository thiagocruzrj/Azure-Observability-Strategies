# =============================================================================
# Module Outputs
# =============================================================================

# -----------------------------------------------------------------------------
# Resource Group
# -----------------------------------------------------------------------------

output "resource_group_name" {
  description = "Name of the resource group"
  value       = local.resource_group_name
}

output "resource_group_id" {
  description = "ID of the resource group"
  value       = local.resource_group_id
}

# -----------------------------------------------------------------------------
# Log Analytics Workspace
# -----------------------------------------------------------------------------

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.main.id
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.main.name
}

output "log_analytics_workspace_primary_key" {
  description = "Primary key of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.main.primary_shared_key
  sensitive   = true
}

output "log_analytics_workspace_workspace_id" {
  description = "Workspace ID (GUID) of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.main.workspace_id
}

# -----------------------------------------------------------------------------
# Application Insights
# -----------------------------------------------------------------------------

output "application_insights" {
  description = "Map of Application Insights resources with their properties"
  value = {
    for k, v in azurerm_application_insights.apps : k => {
      id                  = v.id
      name                = v.name
      instrumentation_key = v.instrumentation_key
      connection_string   = v.connection_string
      app_id              = v.app_id
    }
  }
  sensitive = true
}

output "application_insights_instrumentation_keys" {
  description = "Map of Application Insights instrumentation keys by app name"
  value = {
    for k, v in azurerm_application_insights.apps : k => v.instrumentation_key
  }
  sensitive = true
}

output "application_insights_connection_strings" {
  description = "Map of Application Insights connection strings by app name"
  value = {
    for k, v in azurerm_application_insights.apps : k => v.connection_string
  }
  sensitive = true
}

# -----------------------------------------------------------------------------
# Web Apps
# -----------------------------------------------------------------------------

output "web_apps" {
  description = "Map of Web App resources with their properties"
  value = {
    for k, v in azurerm_windows_web_app.web : k => {
      id               = v.id
      name             = v.name
      default_hostname = v.default_hostname
      outbound_ips     = v.outbound_ip_addresses
      identity         = v.identity[0].principal_id
    }
  }
}

# -----------------------------------------------------------------------------
# Function Apps
# -----------------------------------------------------------------------------

output "function_apps" {
  description = "Map of Function App resources with their properties"
  value = {
    for k, v in azurerm_windows_function_app.function : k => {
      id               = v.id
      name             = v.name
      default_hostname = v.default_hostname
      identity         = v.identity[0].principal_id
    }
  }
}

# -----------------------------------------------------------------------------
# API Apps
# -----------------------------------------------------------------------------

output "api_apps" {
  description = "Map of API App resources with their properties"
  value = {
    for k, v in azurerm_windows_web_app.api : k => {
      id               = v.id
      name             = v.name
      default_hostname = v.default_hostname
      outbound_ips     = v.outbound_ip_addresses
      identity         = v.identity[0].principal_id
    }
  }
}

# -----------------------------------------------------------------------------
# Action Group
# -----------------------------------------------------------------------------

output "action_group_id" {
  description = "ID of the Action Group for alerts"
  value       = var.enable_alerts ? azurerm_monitor_action_group.main[0].id : null
}

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------

output "deployment_summary" {
  description = "Summary of deployed resources"
  value = {
    environment        = var.environment
    location           = var.location
    resource_group     = local.resource_group_name
    web_apps_count     = length(local.web_apps)
    function_apps_count = length(local.function_apps)
    api_apps_count     = length(local.api_apps)
    alerts_enabled     = var.enable_alerts
    locks_enabled      = var.enable_resource_locks
    availability_tests = var.enable_availability_tests
  }
}
