// ============================================================================
// Diagnostic Settings Module for App Service Websites (Microsoft.Web/sites)
// Sends platform logs and metrics to Log Analytics Workspace
// ============================================================================
//
// ⚠️  WARNING: ENABLING DIAGNOSTIC SETTINGS FOR APP SERVICE CAN TRIGGER AN APP RESTART
// ⚠️  Plan deployments during maintenance windows or be prepared for brief service interruption.
// ⚠️  This applies to initial creation and changes to diagnostic settings.
//
// ============================================================================
// FUNCTIONS MONITORING - NOT INCLUDED IN THIS MODULE
// ============================================================================
// Azure Functions are monitored via workspace-based Application Insights (already configured).
// Functions telemetry flows through the Application Insights connection string injected as
// APPLICATIONINSIGHTS_CONNECTION_STRING app setting.
//
// For advanced Functions logging configuration, use host.json settings. These can be
// overridden via app settings using the AzureFunctionsJobHost__<path> pattern:
//
// Example host.json:
//   {
//     "logging": {
//       "logLevel": {
//         "default": "Information",
//         "Host.Results": "Error",
//         "Function": "Warning",
//         "Host.Aggregator": "Trace"
//       }
//     }
//   }
//
// Equivalent app settings overrides:
//   AzureFunctionsJobHost__logging__logLevel__default = "Information"
//   AzureFunctionsJobHost__logging__logLevel__Host.Results = "Error"
//   AzureFunctionsJobHost__logging__logLevel__Function = "Warning"
//   AzureFunctionsJobHost__logging__logLevel__Host.Aggregator = "Trace"
//
// Common override patterns:
//   AzureFunctionsJobHost__logging__fileLoggingMode = "always"
//   AzureFunctionsJobHost__logging__applicationInsights__samplingSettings__isEnabled = "false"
//   AzureFunctionsJobHost__logging__applicationInsights__enableLiveMetrics = "true"
//
// This approach allows logging configuration changes without redeploying code.
// See: https://learn.microsoft.com/azure/azure-functions/functions-host-json
// ============================================================================

// ============================================================================
// Parameters
// ============================================================================

@description('Resource ID of the Log Analytics Workspace to send logs to')
param logAnalyticsWorkspaceId string

@description('Array of App Service website resource IDs (Microsoft.Web/sites) to configure diagnostics for')
param websiteResourceIds array

@description('Enable IP Security Audit logs (optional, may increase log volume)')
param enableIpSecAudit bool = false

@description('Diagnostic setting name suffix for identification')
param diagnosticSettingNameSuffix string = 'law-diag'

// ============================================================================
// Variables
// ============================================================================

// Core log categories for App Service - intentionally selected, not "enable all"
var coreLogCategories = [
  'AppServiceHTTPLogs'       // HTTP request/response logs (access logs)
  'AppServiceConsoleLogs'    // Console output from the application
  'AppServiceAppLogs'        // Application-generated logs
  'AppServiceAuditLogs'      // Audit logs for security/compliance
  'AppServicePlatformLogs'   // Platform-level operational logs
]

// Optional log categories controlled by parameters
var optionalLogCategories = enableIpSecAudit ? ['AppServiceIPSecAuditLogs'] : []

// Combined log categories
var enabledLogCategories = concat(coreLogCategories, optionalLogCategories)

// ============================================================================
// Resources
// ============================================================================

// Create diagnostic settings for each website using extension resource pattern
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = [for (siteResourceId, index) in websiteResourceIds: {
  name: '${last(split(siteResourceId, '/'))}-${diagnosticSettingNameSuffix}'
  scope: existingWebsite[index]
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logAnalyticsDestinationType: 'Dedicated' // Use resource-specific tables for better querying
    logs: [for category in enabledLogCategories: {
      category: category
      enabled: true
    }]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}]

// Reference existing websites to scope the diagnostic settings
resource existingWebsite 'Microsoft.Web/sites@2023-12-01' existing = [for siteResourceId in websiteResourceIds: {
  name: last(split(siteResourceId, '/'))
}]

// ============================================================================
// Outputs
// ============================================================================

@description('Array of diagnostic setting resource IDs created')
output diagnosticSettingIds array = [for (siteResourceId, index) in websiteResourceIds: diagnosticSettings[index].id]

@description('Array of website names that have diagnostic settings configured')
output configuredWebsiteNames array = [for siteResourceId in websiteResourceIds: last(split(siteResourceId, '/'))]

@description('Number of diagnostic settings created')
output diagnosticSettingsCount int = length(websiteResourceIds)

@description('Log categories enabled for each diagnostic setting')
output enabledLogCategories array = enabledLogCategories
