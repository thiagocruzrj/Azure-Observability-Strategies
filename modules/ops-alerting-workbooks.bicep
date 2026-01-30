// ============================================================================
// Operational Layer Module - Alerts, Action Groups, and Workbooks
// Part of the Monitoring Golden Path
// ============================================================================
//
// README
// ------
// This module provisions the operational layer for observability:
// - ONE shared Action Group for all alert notifications
// - Baseline alert rules for App Service, Application Insights, and Functions
// - ONE Azure Monitor Workbook with operational dashboards
//
// Prerequisites:
// - Monitoring resource group exists
// - Log Analytics Workspace exists
// - Workspace-based Application Insights exists per component (web, api, func)
// - App Service diagnostics configured to send platform logs to LAW
//
// Alert Naming Convention:
//   alrt-{env}-{workload}-{component}-{signal}
//   Example: alrt-prod-demoapp-web-5xx
//
// Severity Levels:
//   0 = Critical, 1 = Error, 2 = Warning, 3 = Informational, 4 = Verbose
//   Prod defaults to lower (more severe) values than Dev
//
// Usage:
//   module ops 'modules/ops-alerting-workbooks.bicep' = {
//     scope: resourceGroup(monitoringResourceGroupName)
//     params: {
//       env: 'prod'
//       workload: 'demoapp'
//       location: 'eastus'
//       logAnalyticsWorkspaceId: lawId
//       appInsightsWebId: appiWebId
//       appInsightsApiId: appiApiId
//       appInsightsFuncId: appiFuncId
//       emailAddresses: ['ops-team@company.com']
//       teamsWebhookUrl: 'https://outlook.office.com/webhook/...'
//       tags: requiredTags
//     }
//   }
// ============================================================================

// ============================================================================
// Parameters
// ============================================================================

@description('Environment name (dev or prod)')
@allowed(['dev', 'prod'])
param env string

@description('Workload identifier for naming resources')
param workload string

@description('Azure region for resources')
param location string

@description('Resource ID of the Log Analytics Workspace')
param logAnalyticsWorkspaceId string

@description('Resource ID of the Application Insights for web component')
param appInsightsWebId string

@description('Resource ID of the Application Insights for API component')
param appInsightsApiId string

@description('Resource ID of the Application Insights for Functions component')
param appInsightsFuncId string

@description('Email addresses for alert notifications')
param emailAddresses array

@description('Microsoft Teams webhook URL for notifications (optional)')
param teamsWebhookUrl string = ''

@description('Enable dependency failure alerts (can be noisy)')
param enableDependencyAlerts bool = false

@description('Enable availability test and alert')
param enableAvailabilityTest bool = false

@description('URL to test for availability (required if enableAvailabilityTest is true)')
param availabilityTestUrl string = ''

@description('Tags to apply to resources')
param tags object

// ============================================================================
// Variables - Naming
// ============================================================================

var actionGroupName = 'ag-mon-${env}-${workload}'
var actionGroupShortName = take('ag${env}${workload}', 12) // Max 12 chars

var workbookName = 'wb-ops-${env}-${workload}'
var workbookDisplayName = 'Operations Dashboard - ${env} - ${workload}'

// ============================================================================
// Variables - Alert Severities (prod more strict)
// ============================================================================

var alertSeverities = {
  dev: {
    critical: 1    // Error in dev
    high: 2        // Warning in dev
    medium: 3      // Informational in dev
  }
  prod: {
    critical: 0    // Critical in prod
    high: 1        // Error in prod
    medium: 2      // Warning in prod
  }
}

var severity = alertSeverities[env]

// ============================================================================
// Variables - Alert Thresholds (prod more sensitive)
// ============================================================================

var alertThresholds = {
  dev: {
    http5xxCount: 10           // Allow more errors in dev
    latencyMs: 5000            // 5 seconds
    cpuPercent: 90             // 90%
    memoryPercent: 90          // 90%
    exceptionCount: 20         // More exceptions tolerated
    dependencyFailurePercent: 30
    functionFailureCount: 10
  }
  prod: {
    http5xxCount: 5            // Stricter in prod
    latencyMs: 2000            // 2 seconds
    cpuPercent: 80             // 80%
    memoryPercent: 85          // 85%
    exceptionCount: 5          // Fewer exceptions tolerated
    dependencyFailurePercent: 10
    functionFailureCount: 3
  }
}

var thresholds = alertThresholds[env]

// ============================================================================
// Variables - Evaluation Settings
// ============================================================================

var evaluationFrequency = 'PT5M'     // Every 5 minutes
var windowSize = 'PT15M'             // 15-minute window
var muteActionsDuration = env == 'prod' ? 'PT15M' : 'PT30M' // Shorter mute for prod

// ============================================================================
// Action Group
// ============================================================================

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  location: 'global'
  tags: tags
  properties: {
    groupShortName: actionGroupShortName
    enabled: true
    emailReceivers: [for (email, index) in emailAddresses: {
      name: 'email-${index}'
      emailAddress: email
      useCommonAlertSchema: true
    }]
    webhookReceivers: !empty(teamsWebhookUrl) ? [
      {
        name: 'teams-webhook'
        serviceUri: teamsWebhookUrl
        useCommonAlertSchema: true
      }
    ] : []
  }
}

// ============================================================================
// Alert Rules - App Service 5xx Errors (Log Alert)
// ============================================================================

resource alertWeb5xx 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name: 'alrt-${env}-${workload}-web-5xx'
  location: location
  tags: tags
  properties: {
    displayName: '[${toUpper(env)}] Web - HTTP 5xx Errors'
    description: 'Alerts when HTTP 5xx errors exceed threshold in web application'
    severity: severity.critical
    enabled: true
    evaluationFrequency: evaluationFrequency
    windowSize: windowSize
    scopes: [appInsightsWebId]
    criteria: {
      allOf: [
        {
          query: '''
            requests
            | where resultCode startswith "5"
            | summarize Count = count() by bin(timestamp, 5m)
          '''
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: thresholds.http5xxCount
          failingPeriods: {
            numberOfEvaluationPeriods: 3
            minFailingPeriodsToAlert: 2
          }
        }
      ]
    }
    autoMitigate: true
    muteActionsDuration: muteActionsDuration
    actions: {
      actionGroups: [actionGroup.id]
    }
  }
}

resource alertApi5xx 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name: 'alrt-${env}-${workload}-api-5xx'
  location: location
  tags: tags
  properties: {
    displayName: '[${toUpper(env)}] API - HTTP 5xx Errors'
    description: 'Alerts when HTTP 5xx errors exceed threshold in API application'
    severity: severity.critical
    enabled: true
    evaluationFrequency: evaluationFrequency
    windowSize: windowSize
    scopes: [appInsightsApiId]
    criteria: {
      allOf: [
        {
          query: '''
            requests
            | where resultCode startswith "5"
            | summarize Count = count() by bin(timestamp, 5m)
          '''
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: thresholds.http5xxCount
          failingPeriods: {
            numberOfEvaluationPeriods: 3
            minFailingPeriodsToAlert: 2
          }
        }
      ]
    }
    autoMitigate: true
    muteActionsDuration: muteActionsDuration
    actions: {
      actionGroups: [actionGroup.id]
    }
  }
}

// ============================================================================
// Alert Rules - Latency (Log Alert via App Insights)
// ============================================================================

resource alertWebLatency 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name: 'alrt-${env}-${workload}-web-latency'
  location: location
  tags: tags
  properties: {
    displayName: '[${toUpper(env)}] Web - High Latency'
    description: 'Alerts when average request duration exceeds threshold'
    severity: severity.high
    enabled: true
    evaluationFrequency: evaluationFrequency
    windowSize: windowSize
    scopes: [appInsightsWebId]
    criteria: {
      allOf: [
        {
          query: '''
            requests
            | where success == true
            | summarize AvgDuration = avg(duration) by bin(timestamp, 5m)
          '''
          timeAggregation: 'Average'
          metricMeasureColumn: 'AvgDuration'
          operator: 'GreaterThan'
          threshold: thresholds.latencyMs
          failingPeriods: {
            numberOfEvaluationPeriods: 3
            minFailingPeriodsToAlert: 2
          }
        }
      ]
    }
    autoMitigate: true
    muteActionsDuration: muteActionsDuration
    actions: {
      actionGroups: [actionGroup.id]
    }
  }
}

resource alertApiLatency 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name: 'alrt-${env}-${workload}-api-latency'
  location: location
  tags: tags
  properties: {
    displayName: '[${toUpper(env)}] API - High Latency'
    description: 'Alerts when average request duration exceeds threshold'
    severity: severity.high
    enabled: true
    evaluationFrequency: evaluationFrequency
    windowSize: windowSize
    scopes: [appInsightsApiId]
    criteria: {
      allOf: [
        {
          query: '''
            requests
            | where success == true
            | summarize AvgDuration = avg(duration) by bin(timestamp, 5m)
          '''
          timeAggregation: 'Average'
          metricMeasureColumn: 'AvgDuration'
          operator: 'GreaterThan'
          threshold: thresholds.latencyMs
          failingPeriods: {
            numberOfEvaluationPeriods: 3
            minFailingPeriodsToAlert: 2
          }
        }
      ]
    }
    autoMitigate: true
    muteActionsDuration: muteActionsDuration
    actions: {
      actionGroups: [actionGroup.id]
    }
  }
}

// ============================================================================
// Alert Rules - Exceptions (Log Alert)
// ============================================================================

resource alertWebExceptions 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name: 'alrt-${env}-${workload}-web-exceptions'
  location: location
  tags: tags
  properties: {
    displayName: '[${toUpper(env)}] Web - Exception Spike'
    description: 'Alerts when exception count exceeds threshold'
    severity: severity.high
    enabled: true
    evaluationFrequency: evaluationFrequency
    windowSize: windowSize
    scopes: [appInsightsWebId]
    criteria: {
      allOf: [
        {
          query: '''
            exceptions
            | summarize Count = count() by bin(timestamp, 5m)
          '''
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: thresholds.exceptionCount
          failingPeriods: {
            numberOfEvaluationPeriods: 3
            minFailingPeriodsToAlert: 2
          }
        }
      ]
    }
    autoMitigate: true
    muteActionsDuration: muteActionsDuration
    actions: {
      actionGroups: [actionGroup.id]
    }
  }
}

resource alertApiExceptions 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name: 'alrt-${env}-${workload}-api-exceptions'
  location: location
  tags: tags
  properties: {
    displayName: '[${toUpper(env)}] API - Exception Spike'
    description: 'Alerts when exception count exceeds threshold'
    severity: severity.high
    enabled: true
    evaluationFrequency: evaluationFrequency
    windowSize: windowSize
    scopes: [appInsightsApiId]
    criteria: {
      allOf: [
        {
          query: '''
            exceptions
            | summarize Count = count() by bin(timestamp, 5m)
          '''
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: thresholds.exceptionCount
          failingPeriods: {
            numberOfEvaluationPeriods: 3
            minFailingPeriodsToAlert: 2
          }
        }
      ]
    }
    autoMitigate: true
    muteActionsDuration: muteActionsDuration
    actions: {
      actionGroups: [actionGroup.id]
    }
  }
}

// ============================================================================
// Alert Rules - Azure Functions Failures (Log Alert)
// ============================================================================

resource alertFuncFailures 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name: 'alrt-${env}-${workload}-func-failures'
  location: location
  tags: tags
  properties: {
    displayName: '[${toUpper(env)}] Functions - Execution Failures'
    description: 'Alerts when function execution failures exceed threshold'
    severity: severity.critical
    enabled: true
    evaluationFrequency: evaluationFrequency
    windowSize: windowSize
    scopes: [appInsightsFuncId]
    criteria: {
      allOf: [
        {
          query: '''
            requests
            | where success == false
            | summarize Count = count() by bin(timestamp, 5m)
          '''
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: thresholds.functionFailureCount
          failingPeriods: {
            numberOfEvaluationPeriods: 3
            minFailingPeriodsToAlert: 2
          }
        }
      ]
    }
    autoMitigate: true
    muteActionsDuration: muteActionsDuration
    actions: {
      actionGroups: [actionGroup.id]
    }
  }
}

resource alertFuncExceptions 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name: 'alrt-${env}-${workload}-func-exceptions'
  location: location
  tags: tags
  properties: {
    displayName: '[${toUpper(env)}] Functions - Exception Spike'
    description: 'Alerts when function exceptions exceed threshold'
    severity: severity.high
    enabled: true
    evaluationFrequency: evaluationFrequency
    windowSize: windowSize
    scopes: [appInsightsFuncId]
    criteria: {
      allOf: [
        {
          query: '''
            exceptions
            | summarize Count = count() by bin(timestamp, 5m)
          '''
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: thresholds.exceptionCount
          failingPeriods: {
            numberOfEvaluationPeriods: 3
            minFailingPeriodsToAlert: 2
          }
        }
      ]
    }
    autoMitigate: true
    muteActionsDuration: muteActionsDuration
    actions: {
      actionGroups: [actionGroup.id]
    }
  }
}

// ============================================================================
// Alert Rules - Dependency Failures (Optional, can be noisy)
// ============================================================================

resource alertDependencyFailures 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = if (enableDependencyAlerts) {
  name: 'alrt-${env}-${workload}-all-dependency-failures'
  location: location
  tags: tags
  properties: {
    displayName: '[${toUpper(env)}] All - Dependency Failure Rate'
    description: 'Alerts when dependency failure rate exceeds threshold'
    severity: severity.medium
    enabled: true
    evaluationFrequency: evaluationFrequency
    windowSize: windowSize
    scopes: [logAnalyticsWorkspaceId]
    criteria: {
      allOf: [
        {
          query: '''
            AppDependencies
            | summarize 
                TotalCount = count(),
                FailedCount = countif(Success == false)
                by bin(TimeGenerated, 5m)
            | extend FailurePercent = (FailedCount * 100.0) / TotalCount
            | where TotalCount > 10
          '''
          timeAggregation: 'Average'
          metricMeasureColumn: 'FailurePercent'
          operator: 'GreaterThan'
          threshold: thresholds.dependencyFailurePercent
          failingPeriods: {
            numberOfEvaluationPeriods: 3
            minFailingPeriodsToAlert: 2
          }
        }
      ]
    }
    autoMitigate: true
    muteActionsDuration: muteActionsDuration
    actions: {
      actionGroups: [actionGroup.id]
    }
  }
}

// ============================================================================
// Availability Test (Optional)
// ============================================================================

resource availabilityTest 'Microsoft.Insights/webtests@2022-06-15' = if (enableAvailabilityTest && !empty(availabilityTestUrl)) {
  name: 'avail-${env}-${workload}-web'
  location: location
  tags: union(tags, {
    // Hidden link required for availability test to appear in App Insights
    'hidden-link:${appInsightsWebId}': 'Resource'
  })
  kind: 'ping'
  properties: {
    SyntheticMonitorId: 'avail-${env}-${workload}-web'
    Name: 'Availability - ${workload} Web'
    Description: 'Availability test for ${workload} web application'
    Enabled: true
    Frequency: 300  // 5 minutes
    Timeout: 120    // 2 minutes
    Kind: 'ping'
    RetryEnabled: true
    Locations: [
      { Id: 'us-va-ash-azr' }      // East US
      { Id: 'us-ca-sjc-azr' }      // West US
      { Id: 'emea-nl-ams-azr' }    // West Europe
    ]
    Configuration: {
      WebTest: '''
        <WebTest Name="AvailabilityTest" Enabled="True" Timeout="120" xmlns="http://microsoft.com/schemas/VisualStudio/TeamTest/2010">
          <Items>
            <Request Method="GET" Version="1.1" Url="${availabilityTestUrl}" />
          </Items>
        </WebTest>
      '''
    }
  }
}

// ============================================================================
// Workbook - Operations Dashboard
// ============================================================================

// Workbook content as JSON (Azure Workbook Gallery format)
var workbookContent = {
  version: 'Notebook/1.0'
  items: [
    // ========== Overview Section ==========
    {
      type: 1  // Markdown
      content: {
        json: '''
## 📊 Overview
This dashboard provides operational visibility across all components of the ${workload} workload.
        '''
      }
      name: 'overview-header'
    }
    {
      type: 10  // Metrics
      content: {
        chartId: 'workbook-requests-overview'
        version: 'MetricsItem/2.0'
        size: 1
        chartType: 2
        resourceType: 'microsoft.insights/components'
        metricScope: 0
        resourceParameter: 'appInsightsResources'
        metrics: [
          {
            namespace: 'microsoft.insights/components'
            metric: 'requests/count'
            aggregation: 7
            splitBy: 'cloud/roleName'
          }
        ]
        title: 'Request Volume by Component'
        gridSettings: {
          rowLimit: 10000
        }
      }
      name: 'requests-chart'
    }
    // ========== Failures Section ==========
    {
      type: 1
      content: {
        json: '''
## ❌ Failures
Failed requests and exceptions across all components.
        '''
      }
      name: 'failures-header'
    }
    {
      type: 3  // Query
      content: {
        version: 'KqlItem/1.0'
        query: '''
          union AppRequests, AppExceptions
          | where TimeGenerated > ago(24h)
          | summarize 
              FailedRequests = countif(Success == false and Type == "AppRequests"),
              Exceptions = countif(Type == "AppExceptions")
              by bin(TimeGenerated, 1h), AppRoleName
          | order by TimeGenerated desc
        '''
        size: 1
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
        visualization: 'timechart'
        title: 'Failures Over Time (24h)'
      }
      name: 'failures-chart'
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: '''
          AppExceptions
          | where TimeGenerated > ago(24h)
          | summarize Count = count() by ExceptionType, AppRoleName
          | order by Count desc
          | take 20
        '''
        size: 1
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
        visualization: 'table'
        title: 'Top Exceptions (24h)'
        gridSettings: {
          sortBy: [
            {
              itemKey: 'Count'
              sortOrder: 2
            }
          ]
        }
      }
      name: 'exceptions-table'
    }
    // ========== Dependency Chain Section ==========
    {
      type: 1
      content: {
        json: '''
## 🔗 Dependency Chain
External dependencies and their health status.
        '''
      }
      name: 'dependencies-header'
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: '''
          AppDependencies
          | where TimeGenerated > ago(24h)
          | summarize 
              TotalCalls = count(),
              FailedCalls = countif(Success == false),
              AvgDuration = avg(DurationMs),
              P95Duration = percentile(DurationMs, 95)
              by Target, DependencyType, AppRoleName
          | extend FailureRate = round((FailedCalls * 100.0) / TotalCalls, 2)
          | order by FailureRate desc, TotalCalls desc
          | project 
              Target,
              Type = DependencyType,
              Caller = AppRoleName,
              ['Total Calls'] = TotalCalls,
              ['Failed'] = FailedCalls,
              ['Failure %'] = FailureRate,
              ['Avg (ms)'] = round(AvgDuration, 0),
              ['P95 (ms)'] = round(P95Duration, 0)
        '''
        size: 1
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
        visualization: 'table'
        title: 'Dependency Health (24h)'
        gridSettings: {
          formatters: [
            {
              columnMatch: 'Failure %'
              formatter: 18
              formatOptions: {
                thresholdsOptions: 'colors'
                thresholdsGrid: [
                  {
                    operator: '>='
                    thresholdValue: '10'
                    representation: 'redBright'
                  }
                  {
                    operator: '>='
                    thresholdValue: '5'
                    representation: 'yellow'
                  }
                  {
                    operator: 'Default'
                    representation: 'green'
                  }
                ]
              }
            }
          ]
        }
      }
      name: 'dependencies-table'
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: '''
          AppDependencies
          | where TimeGenerated > ago(4h)
          | summarize AvgDuration = avg(DurationMs) by bin(TimeGenerated, 5m), Target
          | order by TimeGenerated asc
        '''
        size: 1
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
        visualization: 'timechart'
        title: 'Dependency Latency Trend (4h)'
      }
      name: 'dependencies-latency-chart'
    }
    // ========== Recent Alerts Section ==========
    {
      type: 1
      content: {
        json: '''
## 🔔 Recent Alerts
Recently fired alerts for this workload.
        '''
      }
      name: 'alerts-header'
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: '''
          AlertsManagementResources
          | where type == "microsoft.alertsmanagement/alerts"
          | where properties.essentials.startDateTime > ago(7d)
          | extend 
              AlertName = properties.essentials.alertRule,
              Severity = properties.essentials.severity,
              State = properties.essentials.alertState,
              FiredTime = todatetime(properties.essentials.startDateTime),
              TargetResource = tostring(properties.essentials.targetResourceName)
          | where AlertName contains "${workload}" or TargetResource contains "${workload}"
          | project 
              FiredTime,
              AlertName,
              Severity,
              State,
              TargetResource
          | order by FiredTime desc
          | take 50
        '''
        size: 1
        queryType: 1  // Azure Resource Graph
        resourceType: 'microsoft.resourcegraph/resources'
        crossComponentResources: ['Azure subscription']  // Will need subscription context
        visualization: 'table'
        title: 'Recent Alerts (7 days)'
        gridSettings: {
          formatters: [
            {
              columnMatch: 'Severity'
              formatter: 18
              formatOptions: {
                thresholdsOptions: 'colors'
                thresholdsGrid: [
                  {
                    operator: '=='
                    thresholdValue: 'Sev0'
                    representation: 'redBright'
                    text: 'Critical'
                  }
                  {
                    operator: '=='
                    thresholdValue: 'Sev1'
                    representation: 'red'
                    text: 'Error'
                  }
                  {
                    operator: '=='
                    thresholdValue: 'Sev2'
                    representation: 'yellow'
                    text: 'Warning'
                  }
                  {
                    operator: 'Default'
                    representation: 'blue'
                    text: 'Info'
                  }
                ]
              }
            }
            {
              columnMatch: 'State'
              formatter: 18
              formatOptions: {
                thresholdsOptions: 'colors'
                thresholdsGrid: [
                  {
                    operator: '=='
                    thresholdValue: 'New'
                    representation: 'red'
                  }
                  {
                    operator: '=='
                    thresholdValue: 'Acknowledged'
                    representation: 'yellow'
                  }
                  {
                    operator: '=='
                    thresholdValue: 'Closed'
                    representation: 'green'
                  }
                  {
                    operator: 'Default'
                    representation: 'gray'
                  }
                ]
              }
            }
          ]
        }
      }
      name: 'alerts-table'
    }
  ]
  fallbackResourceIds: [logAnalyticsWorkspaceId]
  '$schema': 'https://github.com/Microsoft/Application-Insights-Workbooks/blob/master/schema/workbook.json'
}

resource workbook 'Microsoft.Insights/workbooks@2023-06-01' = {
  name: guid(resourceGroup().id, workbookName)
  location: location
  tags: tags
  kind: 'shared'
  properties: {
    displayName: workbookDisplayName
    serializedData: string(workbookContent)
    version: '1.0'
    category: 'workbook'
    sourceId: logAnalyticsWorkspaceId
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('Resource ID of the Action Group')
output actionGroupId string = actionGroup.id

@description('Resource IDs of all alert rules created')
output alertRuleIds array = [
  alertWeb5xx.id
  alertApi5xx.id
  alertWebLatency.id
  alertApiLatency.id
  alertWebExceptions.id
  alertApiExceptions.id
  alertFuncFailures.id
  alertFuncExceptions.id
]

@description('Resource ID of the Operations Workbook')
output workbookId string = workbook.id

@description('Workbook URL for manual pinning to dashboard')
output workbookUrl string = 'https://portal.azure.com/#@${tenant().tenantId}/resource${workbook.id}/workbook'

@description('Action Group name')
output actionGroupName string = actionGroup.name

@description('Workbook display name')
output workbookDisplayName string = workbookDisplayName
