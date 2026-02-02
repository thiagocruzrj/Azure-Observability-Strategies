// ============================================================================
// Parameters for Operational Layer Deployment - Demo Dev Environment
// ============================================================================
// Usage:
//   az deployment group create \
//     --resource-group rg-obs-demo-dev-weu \
//     --template-file modules/ops-alerting-workbooks.bicep \
//     --parameters examples/ops-params-demo-dev.bicepparam
// ============================================================================

using '../modules/ops-alerting-workbooks.bicep'

param env = 'dev'
param workload = 'demo'
param location = 'westeurope'

// Resource IDs from deployed infrastructure
param logAnalyticsWorkspaceId = '/subscriptions/96c57020-cece-485b-a9a8-25214593bf2d/resourceGroups/rg-obs-demo-dev-weu/providers/Microsoft.OperationalInsights/workspaces/law-obs-demo-dev-weu'
param appInsightsWebId = '/subscriptions/96c57020-cece-485b-a9a8-25214593bf2d/resourceGroups/rg-obs-demo-dev-weu/providers/microsoft.insights/components/appi-web-demo-dev-weu'
param appInsightsApiId = '/subscriptions/96c57020-cece-485b-a9a8-25214593bf2d/resourceGroups/rg-obs-demo-dev-weu/providers/microsoft.insights/components/appi-api-demo-dev-weu'
param appInsightsFuncId = '/subscriptions/96c57020-cece-485b-a9a8-25214593bf2d/resourceGroups/rg-obs-demo-dev-weu/providers/microsoft.insights/components/appi-func-demo-dev-weu'

// Notification settings
param emailAddresses = [
  'ops-team@contoso.com'
]
param teamsWebhookUrl = '' // Optional: 'https://outlook.office.com/webhook/...'

// Optional features (disabled for dev)
param enableDependencyAlerts = false
param enableAvailabilityTest = false
param availabilityTestUrl = ''

// Tags
param tags = {
  env: 'dev'
  workload: 'demo'
  owner: 'platform-team'
  costCenter: 'CC1234'
}
