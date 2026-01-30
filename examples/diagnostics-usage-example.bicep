// ============================================================================
// Example: How to use diagnosticSettings-websites.bicep with App Services
// ============================================================================
// This file demonstrates integration of the diagnostic settings module.
// It is NOT part of the core Monitoring Golden Path deployment.
// Use this as a reference when deploying App Services with observability.
// ============================================================================

// Assuming you have deployed App Service resources, you would call the module like this:

/*
// Example 1: Basic usage with website resource IDs
module websiteDiagnostics 'modules/diagnosticSettings-websites.bicep' = {
  scope: resourceGroup(monitoringResourceGroupName)
  params: {
    logAnalyticsWorkspaceId: foundation.outputs.logAnalyticsWorkspaceId
    websiteResourceIds: [
      webApp.id      // Your web app resource
      apiApp.id      // Your API app resource
    ]
    enableIpSecAudit: false
  }
}

// Example 2: Production with IP Security Audit enabled
module websiteDiagnosticsProd 'modules/diagnosticSettings-websites.bicep' = {
  scope: resourceGroup(monitoringResourceGroupName)
  params: {
    logAnalyticsWorkspaceId: foundation.outputs.logAnalyticsWorkspaceId
    websiteResourceIds: [
      '/subscriptions/${subscription().subscriptionId}/resourceGroups/rg-apps-prod/providers/Microsoft.Web/sites/web-prod-myapp'
      '/subscriptions/${subscription().subscriptionId}/resourceGroups/rg-apps-prod/providers/Microsoft.Web/sites/api-prod-myapp'
    ]
    enableIpSecAudit: true  // Enable for production security compliance
    diagnosticSettingNameSuffix: 'law-diag-prod'
  }
}

// Example 3: Using outputs
output webDiagSettingIds array = websiteDiagnostics.outputs.diagnosticSettingIds
output configuredSites array = websiteDiagnostics.outputs.configuredWebsiteNames
*/

// ============================================================================
// KQL Queries for App Service Logs in Log Analytics
// ============================================================================
// Once diagnostic settings are enabled, use these queries in Log Analytics:
//
// HTTP Access Logs:
//   AppServiceHTTPLogs
//   | where TimeGenerated > ago(1h)
//   | summarize RequestCount = count() by CsHost, CsMethod, ScStatus
//   | order by RequestCount desc
//
// Application Errors:
//   AppServiceAppLogs
//   | where TimeGenerated > ago(24h)
//   | where Level == "Error" or Level == "Critical"
//   | project TimeGenerated, Host, Source, Message
//   | order by TimeGenerated desc
//
// Console Output:
//   AppServiceConsoleLogs
//   | where TimeGenerated > ago(1h)
//   | project TimeGenerated, Host, ResultDescription
//
// Platform Issues:
//   AppServicePlatformLogs
//   | where TimeGenerated > ago(24h)
//   | where Level != "Informational"
//   | project TimeGenerated, Host, Message
//
// Security Audit (if IP Sec Audit enabled):
//   AppServiceIPSecAuditLogs
//   | where TimeGenerated > ago(7d)
//   | where Result == "Denied"
//   | summarize BlockedCount = count() by CIp, Details
// ============================================================================
