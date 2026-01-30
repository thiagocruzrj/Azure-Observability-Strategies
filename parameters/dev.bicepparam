// ============================================================================
// Parameters file for DEV environment
// Usage: az deployment sub create --location eastus --template-file main.bicep --parameters parameters/dev.bicepparam
// ============================================================================

using '../main.bicep'

param env = 'dev'
param workload = 'demoapp'
param owner = 'platform-team'
param costCenter = 'CC1234'
param location = 'eastus'
param logRetentionDays = 14  // Dev: shorter retention for cost savings
param tagPolicyEffect = 'Audit'
