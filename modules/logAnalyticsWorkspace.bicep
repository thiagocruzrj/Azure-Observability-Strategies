// ============================================================================
// Log Analytics Workspace Module
// Deployed at resource group scope
// ============================================================================

// ============================================================================
// Parameters
// ============================================================================

@description('Name of the Log Analytics Workspace')
param workspaceName string

@description('Azure region for the workspace')
param location string

@description('Data retention in days (dev: 14 recommended, prod: 30+ recommended)')
@minValue(7)
@maxValue(730)
param retentionInDays int = 30

@description('Tags to apply to the workspace')
param tags object

// ============================================================================
// Resources
// ============================================================================

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionInDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: -1 // No cap
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('Resource ID of the Log Analytics Workspace')
output workspaceId string = logAnalyticsWorkspace.id

@description('Name of the Log Analytics Workspace')
output workspaceName string = logAnalyticsWorkspace.name
