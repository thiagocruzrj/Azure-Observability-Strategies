// ============================================================================
// Parameters file for DEV environment
// Usage: az deployment sub create --location westeurope --template-file main.bicep --parameters parameters/dev.bicepparam
// ============================================================================

using '../main.bicep'

param env = 'dev'
param workload = 'obs-demo'
param owner = 'platform-team'
param costCenter = 'CC1234'
param location = 'westeurope'
param logRetentionDays = 30  // PerGB2018 SKU minimum is 30 days
param tagPolicyEffect = 'Audit'
