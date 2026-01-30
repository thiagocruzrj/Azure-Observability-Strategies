// ============================================================================
// Parameters Example for Operational Layer (dev environment)
// ============================================================================
// Usage:
//   az deployment group create \
//     --resource-group rg-mon-dev-demoapp \
//     --template-file modules/ops-alerting-workbooks.bicep \
//     --parameters examples/ops-alerting-params-dev.bicepparam
// ============================================================================

using '../modules/ops-alerting-workbooks.bicep'

param env = 'dev'
param workload = 'demoapp'
param location = 'eastus'

// These would come from foundation module outputs in real deployment
param logAnalyticsWorkspaceId = '/subscriptions/<subscription-id>/resourceGroups/rg-mon-dev-demoapp/providers/Microsoft.OperationalInsights/workspaces/law-dev-demoapp'
param appInsightsWebId = '/subscriptions/<subscription-id>/resourceGroups/rg-mon-dev-demoapp/providers/Microsoft.Insights/components/appi-dev-demoapp-web'
param appInsightsApiId = '/subscriptions/<subscription-id>/resourceGroups/rg-mon-dev-demoapp/providers/Microsoft.Insights/components/appi-dev-demoapp-api'
param appInsightsFuncId = '/subscriptions/<subscription-id>/resourceGroups/rg-mon-dev-demoapp/providers/Microsoft.Insights/components/appi-dev-demoapp-func'

// Notification settings
param emailAddresses = [
  'dev-team@company.com'
  'oncall@company.com'
]
param teamsWebhookUrl = '' // Optional: 'https://outlook.office.com/webhook/...'

// Optional features
param enableDependencyAlerts = false  // Can be noisy in dev
param enableAvailabilityTest = false
param availabilityTestUrl = ''

// Tags
param tags = {
  env: 'dev'
  workload: 'demoapp'
  owner: 'platform-team'
  costCenter: 'CC1234'
}
