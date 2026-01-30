// ============================================================================
// Policy Assignment Module - Deployed at Resource Group Scope
// ============================================================================

// ============================================================================
// Parameters
// ============================================================================

@description('Policy definition resource ID to assign')
param policyDefinitionId string

@description('Environment name for naming')
param env string

@description('Workload name for naming')
param workload string

@description('Policy effect: Audit or Deny')
@allowed(['Audit', 'Deny'])
param policyEffect string

@description('List of required tag names')
param requiredTagNames array

@description('Name of the resource group (for display)')
param resourceGroupName string

// ============================================================================
// Variables
// ============================================================================

var policyAssignmentName = 'assign-require-tags-${env}-${workload}'

// ============================================================================
// Resources
// ============================================================================

resource policyAssignment 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: policyAssignmentName
  properties: {
    displayName: 'Enforce mandatory tags on ${resourceGroupName}'
    description: 'Ensures all resources in the monitoring resource group have required tags'
    policyDefinitionId: policyDefinitionId
    parameters: {
      effect: {
        value: policyEffect
      }
    }
    enforcementMode: 'Default'
    nonComplianceMessages: [
      {
        message: 'Resource must have all required tags: ${join(requiredTagNames, ', ')}. Please add missing tags before deployment.'
      }
    ]
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('Policy assignment resource ID')
output policyAssignmentId string = policyAssignment.id

@description('Policy assignment name')
output policyAssignmentName string = policyAssignment.name
