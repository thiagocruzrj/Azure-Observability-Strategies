// ============================================================================
// Policy Tags Module - Enforce Required Tags
// Creates policy definition at subscription scope and assignment via nested module
// ============================================================================

targetScope = 'subscription'

// ============================================================================
// Parameters
// ============================================================================

@description('Name of the resource group to assign policy to')
param resourceGroupName string

@description('Environment name for naming the policy')
param env string

@description('Workload name for naming the policy')
param workload string

@description('Policy effect: Audit (warning only) or Deny (block deployment)')
@allowed(['Audit', 'Deny'])
param policyEffect string = 'Audit'

@description('List of required tag names that must exist on resources')
param requiredTagNames array

// ============================================================================
// Variables
// ============================================================================

var policyDefinitionName = 'policy-require-tags-${env}-${workload}'

// ============================================================================
// Resources
// ============================================================================

// Policy Definition: Require all specified tags to exist
resource policyDefinition 'Microsoft.Authorization/policyDefinitions@2023-04-01' = {
  name: policyDefinitionName
  properties: {
    displayName: 'Require mandatory tags for ${env}-${workload}'
    description: 'Enforces that resources have the required tags: ${join(requiredTagNames, ', ')}. Effect: ${policyEffect}'
    policyType: 'Custom'
    mode: 'Indexed'
    metadata: {
      category: 'Tags'
      version: '1.0.0'
    }
    parameters: {
      effect: {
        type: 'String'
        metadata: {
          displayName: 'Effect'
          description: 'Enable or disable the execution of the policy'
        }
        allowedValues: [
          'Audit'
          'Deny'
        ]
        defaultValue: policyEffect
      }
    }
    policyRule: {
      if: {
        anyOf: [for tagName in requiredTagNames: {
          field: 'tags[\'${tagName}\']'
          exists: 'false'
        }]
      }
      then: {
        effect: '[parameters(\'effect\')]'
      }
    }
  }
}

// Deploy policy assignment using nested module at resource group scope
module policyAssignmentModule 'policy-assignment.bicep' = {
  scope: resourceGroup(resourceGroupName)
  params: {
    policyDefinitionId: policyDefinition.id
    env: env
    workload: workload
    policyEffect: policyEffect
    requiredTagNames: requiredTagNames
    resourceGroupName: resourceGroupName
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('Policy definition resource ID')
output policyDefinitionId string = policyDefinition.id

@description('Policy assignment resource ID')
output policyAssignmentId string = policyAssignmentModule.outputs.policyAssignmentId

@description('Policy definition name')
output policyDefinitionName string = policyDefinition.name
