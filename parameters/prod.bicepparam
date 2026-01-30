// ============================================================================
// Parameters file for PROD environment
// Usage: az deployment sub create --location eastus --template-file main.bicep --parameters parameters/prod.bicepparam
// ============================================================================

using '../main.bicep'

param env = 'prod'
param workload = 'demoapp'
param owner = 'platform-team'
param costCenter = 'CC1234'
param location = 'eastus'
param logRetentionDays = 90
param tagPolicyEffect = 'Deny'
