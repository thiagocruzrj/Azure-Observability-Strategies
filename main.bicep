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

@description('Enable operational layer (alerts, action groups, workbook)')
param enableOpsLayer bool = true

@description('Email addresses for alert notifications (required if enableOpsLayer is true)')
param alertEmailAddresses array = []

@description('Microsoft Teams webhook URL for alert notifications (optional)')
param teamsWebhookUrl string = ''

// ============================================================================
// Variables
// ============================================================================

// Location suffix for resource naming (e.g., westeurope → weu)
var locationSuffixes = {
  westeurope: 'weu'
  eastus: 'eus'
  eastus2: 'eus2'
  centralus: 'cus'
  northeurope: 'neu'
  uksouth: 'uks'
  ukwest: 'ukw'
}
var locationSuffix = contains(locationSuffixes, location) ? locationSuffixes[location] : substring(location, 0, 3)

// Naming convention: {prefix}-{workload}-{env}-{region}
var resourceGroupName = 'rg-${workload}-${env}-${locationSuffix}'
var logAnalyticsWorkspaceName = 'law-${workload}-${env}-${locationSuffix}'

// App Insights naming: appi-{component}-{workload_suffix}-{env}-{region}
// Extract suffix from workload (e.g., obs-demo → demo)
var workloadSuffix = contains(workload, '-') ? last(split(workload, '-')) : workload

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
    appInsightsName: 'appi-web-${workloadSuffix}-${env}-${locationSuffix}'
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
    appInsightsName: 'appi-api-${workloadSuffix}-${env}-${locationSuffix}'
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
    appInsightsName: 'appi-func-${workloadSuffix}-${env}-${locationSuffix}'
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

// ============================================================================
// Operational Layer: Alerts, Action Groups, and Workbook
// ============================================================================

module opsLayer 'modules/ops-alerting-workbooks.bicep' = if (enableOpsLayer && !empty(alertEmailAddresses)) {
  name: 'ops-layer-${env}-${workload}'
  scope: resourceGroup(resourceGroupName)
  params: {
    env: env
    workload: workload
    location: location
    logAnalyticsWorkspaceId: foundation.outputs.logAnalyticsWorkspaceId
    appInsightsWebId: appInsightsWeb.outputs.resourceId
    appInsightsApiId: appInsightsApi.outputs.resourceId
    appInsightsFuncId: appInsightsFunc.outputs.resourceId
    emailAddresses: alertEmailAddresses
    teamsWebhookUrl: teamsWebhookUrl
    enableDependencyAlerts: env == 'prod'  // Enable dependency alerts only in prod
    enableAvailabilityTest: false          // Enable separately with availabilityTestUrl
    tags: requiredTags
  }
}

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

@description('Action Group ID (if ops layer enabled)')
output actionGroupId string = (enableOpsLayer && !empty(alertEmailAddresses)) ? opsLayer.outputs.actionGroupId : 'not-deployed'

@description('Workbook URL (if ops layer enabled)')
output workbookUrl string = (enableOpsLayer && !empty(alertEmailAddresses)) ? opsLayer.outputs.workbookUrl : 'not-deployed'
