// ============================================================================
// Monitoring Golden Path - Main Orchestration
// Deploys a complete observability stack for an environment
// ============================================================================

targetScope = 'subscription'

// ============================================================================
// Parameters
// ============================================================================

@description('Environment name (dev or prod)')
@allowed(['dev', 'prod'])
param env string

@description('Workload identifier for naming resources')
@minLength(3)
@maxLength(20)
param workload string

@description('Owner team or individual responsible for the resources')
@minLength(1)
param owner string

@description('Cost center code for billing purposes')
@minLength(1)
param costCenter string

@description('Azure region for all resources')
param location string = 'eastus'

@description('Log Analytics Workspace retention in days (dev: 14 recommended, prod: 30+ recommended)')
@minValue(7)
@maxValue(730)
param logRetentionDays int = 30

@description('Policy effect for tag enforcement (Audit or Deny)')
@allowed(['Audit', 'Deny'])
param tagPolicyEffect string = 'Audit'

// ============================================================================
// Variables
// ============================================================================

var resourceGroupName = 'rg-mon-${env}-${workload}'
var logAnalyticsWorkspaceName = 'law-${env}-${workload}'

var requiredTags = {
  env: env
  workload: workload
  owner: owner
  costCenter: costCenter
}

// ============================================================================
// Modules
// ============================================================================

// Foundation: Resource Group and Log Analytics Workspace
module foundation 'modules/foundation.bicep' = {
  name: 'foundation-${env}-${workload}'
  params: {
    resourceGroupName: resourceGroupName
    location: location
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    logRetentionDays: logRetentionDays
    tags: requiredTags
  }
}

// Application Insights: Web component
module appInsightsWeb 'modules/appinsights.bicep' = {
  name: 'appinsights-web-${env}-${workload}'
  scope: resourceGroup(resourceGroupName)
  params: {
    appInsightsName: 'appi-${env}-${workload}-web'
    location: location
    logAnalyticsWorkspaceId: foundation.outputs.logAnalyticsWorkspaceId
    applicationType: 'web'
    tags: requiredTags
  }
}

// Application Insights: API component
module appInsightsApi 'modules/appinsights.bicep' = {
  name: 'appinsights-api-${env}-${workload}'
  scope: resourceGroup(resourceGroupName)
  params: {
    appInsightsName: 'appi-${env}-${workload}-api'
    location: location
    logAnalyticsWorkspaceId: foundation.outputs.logAnalyticsWorkspaceId
    applicationType: 'web'
    tags: requiredTags
  }
}

// Application Insights: Function component
module appInsightsFunc 'modules/appinsights.bicep' = {
  name: 'appinsights-func-${env}-${workload}'
  scope: resourceGroup(resourceGroupName)
  params: {
    appInsightsName: 'appi-${env}-${workload}-func'
    location: location
    logAnalyticsWorkspaceId: foundation.outputs.logAnalyticsWorkspaceId
    applicationType: 'web'
    tags: requiredTags
  }
}

// Policy: Enforce required tags on the monitoring resource group
module policyTags 'modules/policy-tags.bicep' = {
  name: 'policy-tags-${env}-${workload}'
  params: {
    resourceGroupName: resourceGroupName
    env: env
    workload: workload
    policyEffect: tagPolicyEffect
    requiredTagNames: ['env', 'workload', 'owner', 'costCenter']
  }
  dependsOn: [foundation]
}

// Operational Layer: Alerts, Action Groups, and Workbook (optional, deploy separately)
// Uncomment and configure when App Insights resources are deployed
// module opsLayer 'modules/ops-alerting-workbooks.bicep' = {
//   name: 'ops-layer-${env}-${workload}'
//   scope: resourceGroup(resourceGroupName)
//   params: {
//     env: env
//     workload: workload
//     location: location
//     logAnalyticsWorkspaceId: foundation.outputs.logAnalyticsWorkspaceId
//     appInsightsWebId: appInsightsWeb.outputs.resourceId
//     appInsightsApiId: appInsightsApi.outputs.resourceId
//     appInsightsFuncId: appInsightsFunc.outputs.resourceId
//     emailAddresses: ['ops-team@company.com']
//     teamsWebhookUrl: ''
//     tags: requiredTags
//   }
// }

// ============================================================================
// Outputs
// ============================================================================

@description('Application Insights connection string for web component')
output appInsightsWebConnectionString string = appInsightsWeb.outputs.connectionString

@description('Application Insights connection string for API component')
output appInsightsApiConnectionString string = appInsightsApi.outputs.connectionString

@description('Application Insights connection string for function component')
output appInsightsFuncConnectionString string = appInsightsFunc.outputs.connectionString

@description('Resource Group name for the monitoring resources')
output resourceGroupName string = resourceGroupName

@description('Log Analytics Workspace resource ID')
output logAnalyticsWorkspaceId string = foundation.outputs.logAnalyticsWorkspaceId
