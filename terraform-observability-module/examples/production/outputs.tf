# =============================================================================
# Production Outputs
# =============================================================================

output "resource_group" {
  description = "Production resource group name"
  value       = module.production.resource_group_name
}

output "log_analytics_workspace_id" {
  description = "Production Log Analytics Workspace ID"
  value       = module.production.log_analytics_workspace_id
}

output "web_apps" {
  description = "Production Web Apps"
  value       = module.production.web_apps
}

output "function_apps" {
  description = "Production Function Apps"
  value       = module.production.function_apps
}

output "app_insights_connection_strings" {
  description = "Production Application Insights connection strings"
  value       = module.production.application_insights_connection_strings
  sensitive   = true
}

output "deployment_summary" {
  description = "Production deployment summary"
  value       = module.production.deployment_summary
}
