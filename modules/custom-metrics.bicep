// ============================================================================
// Custom Metrics & Log-Based Metrics Module
// Part of the Monitoring Golden Path
// ============================================================================
//
// README
// ------
// This module provisions:
// 1. LOG-BASED METRICS - Metrics derived from Log Analytics queries
//    - Create numeric metrics from log data for alerting and dashboards
//    - More flexible than standard metrics but with higher latency (~5 min)
//
// 2. METRIC ALERTS - Alerts on both standard and custom metrics
//    - Business metrics (orders/min, revenue, conversion rate)
//    - Performance metrics (custom latency percentiles)
//
// Key Concepts:
// - Log-based metrics use Microsoft.Insights/scheduledQueryRules
// - Custom metrics are sent from application code via TelemetryClient.TrackMetric() or OpenTelemetry Meter API
// - This module creates the ALERTING infrastructure; app code creates the actual metrics
//
// Prerequisites:
// - Log Analytics Workspace exists
// - Workspace-based Application Insights exists
// - Application sends custom metrics via OTel Meter or TelemetryClient
//
// Usage:
//   module customMetrics 'modules/custom-metrics.bicep' = {
//     scope: resourceGroup(monitoringResourceGroupName)
//     params: {
//       env: 'prod'
//       workload: 'demoapp'
//       location: 'westeurope'
//       logAnalyticsWorkspaceId: lawId
//       appInsightsWebId: appiWebId
//       appInsightsApiId: appiApiId
//       actionGroupId: actionGroupId
//       enableBusinessMetricAlerts: true
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

@description('Resource ID of the Action Group for notifications')
param actionGroupId string

@description('Enable business metric alerts (orders, revenue, etc.)')
param enableBusinessMetricAlerts bool = true

@description('Enable performance log-based metric alerts')
param enablePerformanceMetricAlerts bool = true

@description('Tags to apply to resources')
param tags object

// ============================================================================
// Variables - Naming & Configuration
// ============================================================================

// Naming prefix for log-based metrics
var metricPrefix = 'metric-${env}-${workload}'

// Alert severities (prod more strict)
var severityWarning = env == 'prod' ? 2 : 3
var severityError = env == 'prod' ? 1 : 2

// Thresholds (prod more strict)
var p95ResponseTimeThresholdMs = env == 'prod' ? 2000 : 5000
var errorRateThresholdPercent = env == 'prod' ? 1 : 5
var slowDependencyThresholdCount = env == 'prod' ? 10 : 50

// Suppress unused param warning - kept for future use/documentation
var _ = logAnalyticsWorkspaceId

// ============================================================================
// Log-Based Metrics - Business Metrics (API Component)
// These create metrics from log queries that can be used in dashboards/alerts
// ============================================================================

// ------------------------------
// 1. Orders Per Minute (from requests)
// Alert when order throughput drops significantly
// ------------------------------
resource ordersPerMinuteMetric 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = if (enableBusinessMetricAlerts) {
  name: '${metricPrefix}-orders-per-minute'
  location: location
  tags: tags
  properties: {
    displayName: 'Orders Per Minute'
    description: 'Log-based metric: Count of order requests per minute from API. Alerts when throughput drops.'
    severity: severityWarning
    enabled: true
    evaluationFrequency: 'PT5M'
    scopes: [appInsightsApiId]
    windowSize: 'PT5M'
    criteria: {
      allOf: [
        {
          query: '''
            // Count order-related requests 
            requests
            | where name contains "orders" or url contains "/orders"
            | where success == true
            | summarize OrderCount = count()
          '''
          timeAggregation: 'Average'
          metricMeasureColumn: 'OrderCount'
          operator: 'LessThan'
          threshold: env == 'prod' ? 5 : 0 // Alert if orders drop below threshold (business impact)
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    autoMitigate: true
    actions: {
      actionGroups: [actionGroupId]
    }
  }
}

// ------------------------------
// 2. Failed Orders Rate (business-critical)
// Alert when order failure rate exceeds threshold
// ------------------------------
resource failedOrdersRateMetric 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = if (enableBusinessMetricAlerts) {
  name: '${metricPrefix}-failed-orders-rate'
  location: location
  tags: tags
  properties: {
    displayName: 'Failed Orders Rate (%)'
    description: 'Log-based metric: Percentage of failed order requests'
    severity: severityError
    enabled: true
    evaluationFrequency: 'PT5M'
    scopes: [appInsightsApiId]
    windowSize: 'PT15M'
    criteria: {
      allOf: [
        {
          query: '''
            // Calculate order failure rate
            requests
            | where name contains "orders" or url contains "/orders"
            | summarize 
                TotalOrders = count(),
                FailedOrders = countif(success == false)
            | extend FailureRate = iff(TotalOrders > 0, (FailedOrders * 100.0) / TotalOrders, 0.0)
          '''
          timeAggregation: 'Average'
          metricMeasureColumn: 'FailureRate'
          operator: 'GreaterThan'
          threshold: errorRateThresholdPercent
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    autoMitigate: true
    actions: {
      actionGroups: [actionGroupId]
    }
  }
}

// ------------------------------
// 3. User Sessions Active - Web Component
// Alert when active sessions drop significantly (may indicate outage)
// ------------------------------
resource activeSessionsMetric 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = if (enableBusinessMetricAlerts) {
  name: '${metricPrefix}-active-sessions'
  location: location
  tags: tags
  properties: {
    displayName: 'Active User Sessions'
    description: 'Log-based metric: Count of unique user sessions in last 15 minutes'
    severity: 3 // Informational
    enabled: true
    evaluationFrequency: 'PT5M'
    scopes: [appInsightsWebId]
    windowSize: 'PT15M'
    criteria: {
      allOf: [
        {
          query: '''
            // Count unique sessions
            requests
            | where isnotempty(session_Id)
            | summarize ActiveSessions = dcount(session_Id)
          '''
          timeAggregation: 'Average'
          metricMeasureColumn: 'ActiveSessions'
          operator: 'LessThan'
          threshold: env == 'prod' ? 5 : 0 // Alert if sessions drop significantly
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    autoMitigate: true
    actions: {
      actionGroups: [actionGroupId]
    }
  }
}

// ------------------------------
// 4. Custom Event Rate (for business events tracked via TelemetryClient.TrackEvent)
// Tracks custom business events for dashboard visibility
// ------------------------------
resource customEventRateMetric 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = if (enableBusinessMetricAlerts) {
  name: '${metricPrefix}-custom-events-rate'
  location: location
  tags: tags
  properties: {
    displayName: 'Custom Business Events Rate'
    description: 'Log-based metric: Count of custom business events (for dashboards)'
    severity: 3 // Informational - for dashboards
    enabled: true
    evaluationFrequency: 'PT5M'
    scopes: [appInsightsApiId]
    windowSize: 'PT15M'
    criteria: {
      allOf: [
        {
          query: '''
            // Track custom events by name
            customEvents
            | summarize EventCount = count()
          '''
          timeAggregation: 'Total'
          metricMeasureColumn: 'EventCount'
          operator: 'LessThan'
          threshold: -1 // Never actually alert, just for dashboard visibility
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    autoMitigate: true
    actions: {
      actionGroups: [] // No action - informational only
    }
  }
}

// ============================================================================
// Log-Based Metrics - Performance Metrics (Web Component)
// ============================================================================

// ------------------------------
// 5. P95 Response Time (percentile metric not available in standard metrics)
// Alert when 95th percentile latency exceeds threshold
// ------------------------------
resource p95ResponseTimeWebMetric 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = if (enablePerformanceMetricAlerts) {
  name: '${metricPrefix}-p95-response-time-web'
  location: location
  tags: tags
  properties: {
    displayName: 'P95 Response Time - Web (ms)'
    description: 'Log-based metric: 95th percentile response time for web endpoints'
    severity: severityWarning
    enabled: true
    evaluationFrequency: 'PT5M'
    scopes: [appInsightsWebId]
    windowSize: 'PT15M'
    criteria: {
      allOf: [
        {
          query: '''
            // Calculate P95 response time
            requests
            | where success == true
            | summarize P95_ms = percentile(duration, 95)
          '''
          timeAggregation: 'Average'
          metricMeasureColumn: 'P95_ms'
          operator: 'GreaterThan'
          threshold: p95ResponseTimeThresholdMs
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    autoMitigate: true
    actions: {
      actionGroups: [actionGroupId]
    }
  }
}

// ------------------------------
// 6. P95 Response Time - API Component
// Alert when 95th percentile latency exceeds threshold
// ------------------------------
resource p95ResponseTimeApiMetric 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = if (enablePerformanceMetricAlerts) {
  name: '${metricPrefix}-p95-response-time-api'
  location: location
  tags: tags
  properties: {
    displayName: 'P95 Response Time - API (ms)'
    description: 'Log-based metric: 95th percentile response time for API endpoints'
    severity: severityWarning
    enabled: true
    evaluationFrequency: 'PT5M'
    scopes: [appInsightsApiId]
    windowSize: 'PT15M'
    criteria: {
      allOf: [
        {
          query: '''
            // Calculate P95 response time
            requests
            | where success == true
            | summarize P95_ms = percentile(duration, 95)
          '''
          timeAggregation: 'Average'
          metricMeasureColumn: 'P95_ms'
          operator: 'GreaterThan'
          threshold: p95ResponseTimeThresholdMs
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    autoMitigate: true
    actions: {
      actionGroups: [actionGroupId]
    }
  }
}

// ------------------------------
// 7. Slow Dependencies (external service latency)
// Alert when too many dependencies exceed latency threshold
// ------------------------------
resource slowDependenciesMetric 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = if (enablePerformanceMetricAlerts) {
  name: '${metricPrefix}-slow-dependencies'
  location: location
  tags: tags
  properties: {
    displayName: 'Slow External Dependencies'
    description: 'Log-based metric: Count of dependencies exceeding 3s latency threshold'
    severity: severityWarning
    enabled: true
    evaluationFrequency: 'PT5M'
    scopes: [appInsightsApiId]
    windowSize: 'PT15M'
    criteria: {
      allOf: [
        {
          query: '''
            // Count slow dependencies
            dependencies
            | where duration > 3000 // Over 3 seconds
            | summarize SlowDependencies = count()
          '''
          timeAggregation: 'Total'
          metricMeasureColumn: 'SlowDependencies'
          operator: 'GreaterThan'
          threshold: slowDependencyThresholdCount
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    autoMitigate: true
    actions: {
      actionGroups: [actionGroupId]
    }
  }
}

// ------------------------------
// 8. Unique Exceptions Count (tracks new exception types)
// Alert when many unique exception types appear (indicates systemic issues)
// ------------------------------
resource uniqueExceptionsMetric 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = if (enablePerformanceMetricAlerts) {
  name: '${metricPrefix}-unique-exceptions'
  location: location
  tags: tags
  properties: {
    displayName: 'Unique Exception Types'
    description: 'Log-based metric: Count of distinct exception types (spike indicates new issues)'
    severity: severityWarning
    enabled: true
    evaluationFrequency: 'PT5M'
    scopes: [appInsightsApiId]
    windowSize: 'PT30M'
    criteria: {
      allOf: [
        {
          query: '''
            // Count unique exception types
            exceptions
            | summarize UniqueTypes = dcount(type)
          '''
          timeAggregation: 'Average'
          metricMeasureColumn: 'UniqueTypes'
          operator: 'GreaterThan'
          threshold: env == 'prod' ? 5 : 10 // More than N unique exception types suggests systemic issues
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    autoMitigate: true
    actions: {
      actionGroups: [actionGroupId]
    }
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('List of deployed log-based metric alert names')
output logBasedMetricNames array = [
  enableBusinessMetricAlerts ? ordersPerMinuteMetric.name : ''
  enableBusinessMetricAlerts ? failedOrdersRateMetric.name : ''
  enableBusinessMetricAlerts ? activeSessionsMetric.name : ''
  enableBusinessMetricAlerts ? customEventRateMetric.name : ''
  enablePerformanceMetricAlerts ? p95ResponseTimeWebMetric.name : ''
  enablePerformanceMetricAlerts ? p95ResponseTimeApiMetric.name : ''
  enablePerformanceMetricAlerts ? slowDependenciesMetric.name : ''
  enablePerformanceMetricAlerts ? uniqueExceptionsMetric.name : ''
]

@description('Number of log-based metrics deployed')
output metricsCount int = (enableBusinessMetricAlerts ? 4 : 0) + (enablePerformanceMetricAlerts ? 4 : 0)
