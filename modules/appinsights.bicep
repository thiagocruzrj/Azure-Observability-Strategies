// ============================================================================
// Application Insights Module (Workspace-Based)
// Modern workspace-based Application Insights attached to Log Analytics
// ============================================================================

// ============================================================================
// Parameters
// ============================================================================

@description('Name of the Application Insights resource')
param appInsightsName string

@description('Azure region for the resource')
param location string

@description('Resource ID of the Log Analytics Workspace to attach to')
param logAnalyticsWorkspaceId string

@description('Type of application being monitored')
@allowed(['web', 'other'])
param applicationType string = 'web'

@description('Tags to apply to the resource')
param tags object

// ============================================================================
// Resources
// ============================================================================

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: applicationType
  properties: {
    Application_Type: applicationType
    WorkspaceResourceId: logAnalyticsWorkspaceId
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    RetentionInDays: 90
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('Connection string for the Application Insights resource')
output connectionString string = appInsights.properties.ConnectionString

@description('Resource ID of the Application Insights resource')
output resourceId string = appInsights.id

@description('Name of the Application Insights resource')
output name string = appInsights.name
