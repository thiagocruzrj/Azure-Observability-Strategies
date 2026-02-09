# =============================================================================
# Staging Outputs
# =============================================================================

output "resource_group" {
  description = "Staging resource group name"
  value       = module.staging.resource_group_name
}

output "log_analytics_workspace_id" {
  description = "Staging Log Analytics Workspace ID"
  value       = module.staging.log_analytics_workspace_id
}

output "web_apps" {
  description = "Staging Web Apps"
  value       = module.staging.web_apps
}

output "function_apps" {
  description = "Staging Function Apps"
  value       = module.staging.function_apps
}

output "api_apps" {
  description = "Staging API Apps"
  value       = module.staging.api_apps
}

output "app_insights_connection_strings" {
  description = "Staging Application Insights connection strings"
  value       = module.staging.application_insights_connection_strings
  sensitive   = true
}

output "deployment_summary" {
  description = "Staging deployment summary"
  value       = module.staging.deployment_summary
}
