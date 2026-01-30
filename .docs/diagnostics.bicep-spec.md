Implement "Logs / platform telemetry" for the Monitoring Golden Path using Azure Bicep.

Scope
- Diagnostic settings must be created for each App Service (Web/API) resource of type Microsoft.Web/sites.
- Send logs to the existing Log Analytics Workspace (LAW) only.
- Diagnostic settings should NOT be enabled “for everything”; pick categories intentionally (listed below).

Non-negotiables
1) Diagnostic settings resource type must be Microsoft.Insights/diagnosticSettings scoped to each Microsoft.Web/sites resource.
2) Destination: properties.workspaceId = <LAW resourceId>.
3) Enable only these log categories for App Services (Microsoft.Web/sites):
   - AppServiceHTTPLogs
   - AppServiceConsoleLogs
   - AppServiceAppLogs
   - AppServiceAuditLogs
   - AppServicePlatformLogs
   Optional (behind a boolean parameter default false):
   - AppServiceIPSecAuditLogs
4) Also send metrics = AllMetrics (enabled = true).
5) Include a comment in the module warning that enabling diagnostic settings for App Service can trigger an app restart.
6) Tags: apply standard tags to the diagnostic setting resource (if supported in that api version) OR at least ensure tags are applied on parent resources (RG, sites, LAW).
7) The module must be reusable: accept an array of site resource IDs (web + api) and a LAW id, then loop to create one diagnostic setting per site with stable naming.

Functions monitoring
- Do NOT create diagnostic settings for Functions in this module.
- Functions are monitored via workspace-based Application Insights connection string (already created) and host logging tuning via host.json when needed.
- Provide a short README comment section describing how host.json settings can be overridden via app settings using AzureFunctionsJobHost__... keys (do not deploy host.json via Bicep here).

Deliverable
- Generate a Bicep module: modules/diagnosticSettings-websites.bicep
- It must accept:
  - param logAnalyticsWorkspaceId string
  - param websiteResourceIds array
  - param enableIpSecAudit bool = false
- Output the diagnostic setting resource IDs created.
