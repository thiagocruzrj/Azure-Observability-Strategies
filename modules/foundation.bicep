// ============================================================================
// Foundation Module - Resource Group and Log Analytics Workspace
// ============================================================================

targetScope = 'subscription'

// ============================================================================
// Parameters
// ============================================================================

@description('Name of the monitoring resource group')
param resourceGroupName string

@description('Azure region for all resources')
param location string

@description('Name of the Log Analytics Workspace')
param logAnalyticsWorkspaceName string

@description('Log Analytics Workspace retention in days (dev: 14 recommended, prod: 30+ recommended)')
@minValue(7)
@maxValue(730)
param logRetentionDays int = 30

@description('Tags to apply to all resources')
param tags object

// ============================================================================
// Resources
// ============================================================================

// Monitoring Resource Group
resource monitoringResourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// Log Analytics Workspace (deployed into the resource group)
module logAnalyticsWorkspace 'logAnalyticsWorkspace.bicep' = {
  scope: monitoringResourceGroup
  params: {
    workspaceName: logAnalyticsWorkspaceName
    location: location
    retentionInDays: logRetentionDays
    tags: tags
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('Resource ID of the Log Analytics Workspace')
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.outputs.workspaceId

@description('Name of the monitoring resource group')
output resourceGroupName string = monitoringResourceGroup.name
