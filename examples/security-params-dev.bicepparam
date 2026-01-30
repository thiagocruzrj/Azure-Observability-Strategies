// ============================================================================
// Parameters Example for Security/Governance Module
// ============================================================================
// Usage:
//   az deployment group create \
//     --resource-group rg-mon-dev-demoapp \
//     --template-file modules/security-observability.bicep \
//     --parameters examples/security-params-dev.bicepparam
//
// To get principal IDs:
//   # For a user:
//   az ad user show --id "user@company.com" --query id -o tsv
//
//   # For a group:
//   az ad group show --group "Monitoring-Readers" --query id -o tsv
//
//   # For a service principal:
//   az ad sp show --id "app-id-or-name" --query id -o tsv
// ============================================================================

using '../modules/security-observability.bicep'

// Read-only monitoring access
// Typically: operations team, developers, support staff
param monitoringReadersPrincipalIds = [
  // 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'  // Dev Team Group
  // 'yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy'  // Support Team Group
]
param readersPrincipalType = 'Group'

// Monitoring contributor access
// Typically: SRE team, platform team, senior developers
param monitoringContributorsPrincipalIds = [
  // 'zzzzzzzz-zzzz-zzzz-zzzz-zzzzzzzzzzzz'  // SRE Team Group
  // 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'  // Platform Team Group
]
param contributorsPrincipalType = 'Group'
