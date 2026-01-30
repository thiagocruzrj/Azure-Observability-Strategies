You are generating production-quality Azure Bicep.

Goal: implement a “Monitoring Golden Path” for an environment (dev/prod).

NON-NEGOTIABLE RULES
1) Create ONE dedicated Resource Group named using: rg-mon-${env}-${workload}. Scope: subscription.
2) Enforce REQUIRED TAGS on EVERY resource and RG:
   - env (dev|prod)
   - workload (string)
   - owner (string)
   - costCenter (string)
3) Create ONE Log Analytics Workspace (LAW) in the monitoring RG:
   - name: law-${env}-${workload}
   - retentionInDays: 30 (parameterize)
   - sku: PerGB2018
4) Create workspace-based Application Insights (modern model) and attach each to the LAW:
   - one per component: web, api, func
   - names: appi-${env}-${workload}-web / -api / -func
   - MUST be workspace-based (NOT classic)
5) Outputs:
   - output the Application Insights CONNECTION STRINGS for web/api/func.
   - Do NOT output instrumentation keys. Do NOT mention instrumentation keys.
6) Add Azure Policy to enforce the required tags:
   - Start with effect = "Audit" (parameterize effect so it can be switched to "Deny" later, especially for prod).
   - Assign policy at the monitoring RG scope.
   - The policy should require these 4 tags to exist (existence check).
7) Use best-practice Bicep structure:
   - main.bicep orchestrates modules
   - modules: foundation (RG+LAW), appInsights (3 components), policyTags (definition+assignment)
   - strong parameter validation (allowed values) and consistent naming/variables
   - use `resourceGroup()` and `subscription()` scopes correctly

DELIVERABLE
Generate the Bicep code files:
- main.bicep
- modules/foundation.bicep
- modules/appInsights.bicep
- modules/policyTags.bicep

Also include a minimal example parameters file (json) for env=dev, workload="demoapp", owner="platform-team", costCenter="CC1234".
