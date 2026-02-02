// ============================================================================
// Compute Module - App Service Plan, Web/API Apps, Storage, Function App
// Deploys the three-tier compute resources for the observability demo
// ============================================================================

// ============================================================================
// Parameters
// ============================================================================

@description('Environment name (dev or prod)')
@allowed(['dev', 'prod'])
param env string

@description('Workload identifier')
param workload string

@description('Azure region')
param location string = resourceGroup().location

@description('Location suffix for naming (e.g., weu for westeurope)')
param locationSuffix string = 'weu'

@description('App Service Plan SKU')
@allowed(['B1', 'B2', 'B3', 'S1', 'S2', 'S3', 'P0v3', 'P1v3'])
param appServicePlanSku string = 'B1'

@description('Application Insights connection string for Web app')
@secure()
param appInsightsWebConnectionString string

@description('Application Insights connection string for API app')
@secure()
param appInsightsApiConnectionString string

@description('Application Insights connection string for Function app')
@secure()
param appInsightsFuncConnectionString string

@description('Tags to apply to all resources')
param tags object

// ============================================================================
// Variables
// ============================================================================

// Extract workload suffix (e.g., obs-demo → demo)
var workloadSuffix = contains(workload, '-') ? last(split(workload, '-')) : workload

// Resource names following spec convention
var appServicePlanName = 'asp-${workload}-${env}-${locationSuffix}'
var webAppName = 'web-${workload}-${env}-${locationSuffix}'
var apiAppName = 'api-${workload}-${env}-${locationSuffix}'
var funcAppName = 'func-${workload}-${env}-${locationSuffix}'
var storageAccountName = 'st${replace(workloadSuffix, '-', '')}${env}${locationSuffix}'

// ============================================================================
// Resources
// ============================================================================

// Storage Account for Function App
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    networkAcls: {
      defaultAction: 'Allow'
    }
  }
}

// App Service Plan (Linux)
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: appServicePlanName
  location: location
  tags: tags
  kind: 'linux'
  sku: {
    name: appServicePlanSku
  }
  properties: {
    reserved: true // Required for Linux
  }
}

// Web App (ASP.NET Core)
resource webApp 'Microsoft.Web/sites@2023-01-01' = {
  name: webAppName
  location: location
  tags: tags
  kind: 'app,linux'
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|9.0'
      alwaysOn: appServicePlanSku != 'B1' // AlwaysOn not available on Basic
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      http20Enabled: true
      appSettings: [
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsWebConnectionString
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'Api__BaseUrl'
          value: 'https://${apiAppName}.azurewebsites.net'
        }
      ]
    }
  }
}

// API App (ASP.NET Core)
resource apiApp 'Microsoft.Web/sites@2023-01-01' = {
  name: apiAppName
  location: location
  tags: tags
  kind: 'app,linux'
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|9.0'
      alwaysOn: appServicePlanSku != 'B1'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      http20Enabled: true
      appSettings: [
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsApiConnectionString
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'Function__BaseUrl'
          value: 'https://${funcAppName}.azurewebsites.net'
        }
      ]
    }
  }
}

// Function App - Uses shared App Service Plan (avoids Linux Consumption limitation)
// Note: Linux Consumption Functions can't coexist with Linux App Service in same RG in some regions
resource functionApp 'Microsoft.Web/sites@2023-01-01' = {
  name: funcAppName
  location: location
  tags: tags
  kind: 'functionapp,linux'
  properties: {
    serverFarmId: appServicePlan.id  // Share the App Service Plan
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'DOTNET-ISOLATED|9.0'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      alwaysOn: appServicePlanSku != 'B1'
      appSettings: [
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsFuncConnectionString
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet-isolated'
        }
      ]
    }
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('Web App default hostname')
output webAppHostname string = webApp.properties.defaultHostName

@description('API App default hostname')
output apiAppHostname string = apiApp.properties.defaultHostName

@description('Function App default hostname')
output functionAppHostname string = functionApp.properties.defaultHostName

@description('Web App resource ID')
output webAppId string = webApp.id

@description('API App resource ID')
output apiAppId string = apiApp.id

@description('Function App resource ID')
output functionAppId string = functionApp.id

@description('Storage Account name')
output storageAccountName string = storageAccount.name
