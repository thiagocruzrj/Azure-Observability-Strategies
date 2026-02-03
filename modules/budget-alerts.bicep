// ============================================================================
// Budget Alert Module - Log Analytics Cost Monitoring
// Part of the Monitoring Golden Path
// ============================================================================
//
// README
// ------
// This module creates an Azure Budget with alerts for Log Analytics costs.
// Helps prevent unexpected cost spikes from telemetry ingestion.
//
// Prerequisites:
// - Subscription-level deployment scope (budgets are subscription resources)
// - Budget alerts require notification email addresses
//
// Cost Estimation:
// - Log Analytics: ~$2.30/GB ingested (pay-as-you-go)
// - Typical App Insights: 1-5 GB/day for medium workload
// - Monthly estimate: 30 days × 3 GB/day × $2.30 = ~$207/month
//
// Usage:
//   module budget 'modules/budget-alerts.bicep' = {
//     name: 'budget-alerts-${env}'
//     params: {
//       budgetName: 'budget-monitoring-${env}'
//       amount: 500  // Monthly budget in USD
//       contactEmails: ['platform-team@company.com']
//       resourceGroupFilter: 'rg-myapp-${env}-weu'
//     }
//   }
// ============================================================================

targetScope = 'subscription'

// ============================================================================
// Parameters
// ============================================================================

@description('Name for the budget')
param budgetName string

@description('Monthly budget amount in USD')
@minValue(1)
param amount int

@description('Email addresses for budget notifications')
param contactEmails array

@description('Resource group to filter costs (optional)')
param resourceGroupFilter string = ''

@description('Start date for the budget (defaults to first of current month)')
param startDate string = '${utcNow('yyyy')}-${utcNow('MM')}-01'

@description('Environment tag for categorization')
param env string = 'dev'

// ============================================================================
// Variables
// ============================================================================

var thresholds = [
  { percentage: 50, type: 'Actual' }    // 50% actual spend
  { percentage: 75, type: 'Actual' }    // 75% actual spend
  { percentage: 90, type: 'Actual' }    // 90% actual spend
  { percentage: 100, type: 'Forecasted' } // 100% forecasted
]

// ============================================================================
// Budget Resource
// ============================================================================

resource budget 'Microsoft.Consumption/budgets@2023-11-01' = {
  name: budgetName
  properties: {
    category: 'Cost'
    amount: amount
    timeGrain: 'Monthly'
    timePeriod: {
      startDate: startDate
    }
    filter: !empty(resourceGroupFilter) ? {
      dimensions: {
        name: 'ResourceGroupName'
        operator: 'In'
        values: [resourceGroupFilter]
      }
    } : {}
    notifications: {
      threshold50Actual: {
        enabled: true
        operator: 'GreaterThan'
        threshold: 50
        thresholdType: 'Actual'
        contactEmails: contactEmails
        locale: 'en-us'
      }
      threshold75Actual: {
        enabled: true
        operator: 'GreaterThan'
        threshold: 75
        thresholdType: 'Actual'
        contactEmails: contactEmails
        locale: 'en-us'
      }
      threshold90Actual: {
        enabled: true
        operator: 'GreaterThan'
        threshold: 90
        thresholdType: 'Actual'
        contactEmails: contactEmails
        locale: 'en-us'
      }
      threshold100Forecasted: {
        enabled: true
        operator: 'GreaterThan'
        threshold: 100
        thresholdType: 'Forecasted'
        contactEmails: contactEmails
        locale: 'en-us'
      }
    }
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('Budget resource ID')
output budgetId string = budget.id

@description('Budget name')
output budgetName string = budget.name

@description('Monthly budget amount')
output budgetAmount int = amount

@description('Alert thresholds configured')
output alertThresholds array = ['50% actual', '75% actual', '90% actual', '100% forecasted']
