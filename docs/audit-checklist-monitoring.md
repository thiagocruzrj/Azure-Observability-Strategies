# Azure Monitoring Audit Checklist

> **Purpose**: Comprehensive audit checklist for assessing Azure App Services monitoring implementations  
> **Access Required**: Reader role on target subscriptions  
> **Version**: 2.1  
> **Date**: February 3, 2026  
> **Script**: See [`scripts/multi-subscription-audit.sh`](../scripts/multi-subscription-audit.sh) (Bash)  
> **Quick Commands**: See [`docs/multi-subscription-quick-commands.md`](multi-subscription-quick-commands.md)

---

## Table of Contents

1. [Pre-Audit Setup](#1-pre-audit-setup)
2. [Multi-Subscription Discovery](#2-multi-subscription-discovery) ⭐ NEW
3. [Subscription Inventory](#3-subscription-inventory)
4. [Monitoring Strategy Assessment](#4-monitoring-strategy-assessment)
5. [Naming Conventions Audit](#5-naming-conventions-audit)
6. [Tagging Compliance Audit](#6-tagging-compliance-audit)
7. [Application Insights Configuration](#7-application-insights-configuration)
8. [Log Analytics Workspace Assessment](#8-log-analytics-workspace-assessment)
9. [Distributed Tracing & Correlation](#9-distributed-tracing--correlation)
10. [Sampling Configuration](#10-sampling-configuration)
11. [Retention & Cost Optimization](#11-retention--cost-optimization)
12. [Alerting & Action Groups](#12-alerting--action-groups)
13. [Diagnostic Settings](#13-diagnostic-settings)
14. [RBAC & Security](#14-rbac--security)
15. [Azure Monitor Configuration](#15-azure-monitor-configuration) ⭐ NEW
16. [Governance & Policies](#16-governance--policies)
17. [Workbooks & Dashboards](#17-workbooks--dashboards)
18. [Scoring Matrix](#18-scoring-matrix)
19. [Remediation Priorities](#19-remediation-priorities)

---

## 1. Pre-Audit Setup

### 1.1 Prerequisites Checklist

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1.1.1 | Azure CLI installed and updated | ⬜ | `az version` |
| 1.1.2 | Reader access confirmed on all target subscriptions | ⬜ | |
| 1.1.3 | List of subscriptions to audit documented | ⬜ | |
| 1.1.4 | Audit output folder created | ⬜ | |
| 1.1.5 | Client's current monitoring documentation obtained | ⬜ | |
| 1.1.6 | Multi-subscription audit scripts ready | ⬜ | `scripts/multi-subscription-audit.sh` or `.ps1` |
| 1.1.7 | Azure Resource Graph access confirmed | ⬜ | Fastest cross-subscription queries |

### 1.2 Login and Subscription Setup

```bash
# Login to Azure
az login

# List all accessible subscriptions
az account list --query "[].{Name:name, Id:id, State:state}" -o table > subscriptions.txt

# Set subscription context (repeat for each subscription)
az account set --subscription "<subscription-id>"

# Verify access level
az role assignment list --assignee $(az ad signed-in-user show --query id -o tsv) \
  --query "[].{Role:roleDefinitionName, Scope:scope}" -o table
```

### 1.3 Export Subscription List

```bash
# Create audit inventory
az account list --query "[?state=='Enabled'].{
  SubscriptionName:name,
  SubscriptionId:id,
  TenantId:tenantId
}" -o json > audit-subscriptions.json
```

---

## 2. Multi-Subscription Discovery

> **Why this matters**: Most enterprise clients have multiple subscriptions. Auditing them one-by-one is slow and error-prone. Use Azure Resource Graph for instant cross-subscription queries, or the provided scripts for comprehensive audits.

### 2.1 Quick Discovery with Azure Resource Graph

Azure Resource Graph provides **instant cross-subscription queries** without switching subscription context.

> ⚠️ **CRITICAL TIPS**:
> 1. By default, `az graph query` only queries the **current subscription** - use `--subscriptions`!
> 2. Use `=~` (case-insensitive) instead of `==` for type matching
> 3. Add `--first 1000` to get all results (pagination)
> 4. Add `--query "data"` to extract actual results (otherwise you get metadata!)

```bash
# ============================================================
# SETUP: Run this first to enable cross-subscription queries
# ============================================================
# Option 1: All enabled subscriptions
# ALL_SUBS=$(az account list --query "[?state=='Enabled'].id" -o tsv | tr -d '\r' | tr '\n' ' ')

# Option 2: Specific target subscriptions (RECOMMENDED for this audit)
ALL_SUBS="76cd0ab7-9ab0-412a-b927-cc10e3d656d3 039c62ed-7e0c-4d56-bb3f-be23033758ce 98d67ae7-6840-4bbb-a9db-23f12702daec 8300de04-726b-4119-8637-1920254b613b 4f9b5670-6e01-452b-9068-534c3e8b80fd 04669dbd-24c3-4cbe-a6a0-dbae82a9cb91 658a3795-22d3-4ac1-a87c-70810b337754 2e3c305c-04a8-48f7-b8f7-e615c5bf8669 1d08dafe-eb6c-4aa7-b738-a851f0959ba7"

echo "Loaded $(echo $ALL_SUBS | wc -w) subscriptions"
# Target subscriptions:
# - Edv2 BR QA
# - EVASM NEU PRO, EVASM NEU QA, EVASM WUS PRO (LATAM)
# - MAE LATAM PRO, MAE NEU PRO, MAE NEU QA
# - RecursosInternos-DevOps, RecursosInternos-DevOps QA
```

#### 2.1.1 App Services Inventory (Web Apps, Function Apps, API Apps)

```bash
# Total count by type across ALL subscriptions
az graph query -q "Resources 
| where type =~ 'microsoft.web/sites'
| extend appType = case(
    kind contains 'functionapp', 'Function App',
    kind contains 'api', 'API App',
    'Web App')
| summarize Total=count() by appType
| order by Total desc" \
  --subscriptions $ALL_SUBS --first 1000 --query "data" -o table
```

#### 2.1.2 Application Insights - Total Count

```bash
# Total Application Insights across tenant
az graph query -q "Resources 
| where type =~ 'microsoft.insights/components' 
| count" \
  --subscriptions $ALL_SUBS --first 1000
```

#### 2.1.3 Log Analytics Workspaces - Total Count

```bash
# Total Log Analytics Workspaces across tenant
az graph query -q "Resources 
| where type =~ 'microsoft.operationalinsights/workspaces' 
| count" \
  --subscriptions $ALL_SUBS --first 1000

# Detailed list with retention settings
az graph query -q "Resources 
| where type =~ 'microsoft.operationalinsights/workspaces' 
| project name, subscriptionId, resourceGroup, 
          retention=properties.retentionInDays, 
          sku=properties.sku.name
| order by subscriptionId, name" \
  --subscriptions $ALL_SUBS --first 1000 --query "data" -o table
```

#### 2.1.4 App Services WITHOUT Application Insights

```bash
# List all Web Apps, Function Apps, and API Apps missing App Insights connection string
az graph query -q "Resources
| where type =~ 'microsoft.web/sites'
| extend appType = case(
    kind contains 'functionapp', 'Function App',
    kind contains 'api', 'API App',
    'Web App')
| mv-expand setting = properties.siteConfig.appSettings
| summarize hasAppInsights = countif(setting.name == 'APPLICATIONINSIGHTS_CONNECTION_STRING') by name, appType, subscriptionId, resourceGroup
| where hasAppInsights == 0
| project name, appType, subscriptionId, resourceGroup
| order by appType, name" \
  --subscriptions $ALL_SUBS --first 1000 --query "data" -o table

# Count of apps WITHOUT App Insights by type
az graph query -q "Resources
| where type =~ 'microsoft.web/sites'
| extend appType = case(
    kind contains 'functionapp', 'Function App',
    kind contains 'api', 'API App',
    'Web App')
| mv-expand setting = properties.siteConfig.appSettings
| summarize hasAppInsights = countif(setting.name == 'APPLICATIONINSIGHTS_CONNECTION_STRING') by name, appType
| where hasAppInsights == 0
| summarize MissingAppInsights=count() by appType
| order by MissingAppInsights desc" \
  --subscriptions $ALL_SUBS --first 1000 --query "data" -o table
```

#### 2.1.5 Alert Rules for App Services (Web Apps, Function Apps, API Apps)

```bash
# All metric alerts targeting App Services
az graph query -q "Resources
| where type =~ 'microsoft.insights/metricalerts'
| mv-expand scope = properties.scopes
| where scope contains 'microsoft.web/sites'
| project alertName=name, subscriptionId, resourceGroup, 
          severity=properties.severity, 
          enabled=properties.enabled,
          targetResource=split(scope, '/')[8]
| order by subscriptionId, alertName" \
  --subscriptions $ALL_SUBS --first 1000 --query "data" -o table

# All scheduled query (log) alerts for App Services
az graph query -q "Resources
| where type =~ 'microsoft.insights/scheduledqueryrules'
| mv-expand scope = properties.scopes
| where scope contains 'microsoft.insights/components' or scope contains 'microsoft.operationalinsights/workspaces'
| project alertName=name, subscriptionId, resourceGroup,
          severity=properties.severity,
          enabled=properties.enabled,
          description=properties.description
| order by subscriptionId, alertName" \
  --subscriptions $ALL_SUBS --first 1000 --query "data" -o table

# Summary: Total alert rules by type
az graph query -q "Resources 
| where type in~ ('microsoft.insights/metricalerts', 'microsoft.insights/scheduledqueryrules')
| extend alertType = case(
    type =~ 'microsoft.insights/metricalerts', 'Metric Alert',
    'Scheduled Query Alert')
| summarize Total=count() by alertType" \
  --subscriptions $ALL_SUBS --first 1000 --query "data" -o table

# Alert types by metric
 echo "=== Alert Rules by Metric Type ===" && az graph query -q "Resources | where type =~ 'microsoft.insights/metricalerts' | extend metricName = tostring(properties.criteria.allOf[0].metricName) | summarize Total=count() by metricName | order by Total desc" --subscriptions $ALL_SUBS --first 1000 --query "data" -o table
```

### 2.2 Multi-Subscription Discovery Checklist

> 💡 **Remember**: Add `--subscriptions $ALL_SUBS` to all Resource Graph queries!

| # | Check | Command | Finding | Score |
|---|-------|---------|---------|-------|
| 2.2.1 | Total subscriptions in scope | `echo $ALL_SUBS | wc -w` | 9 | |
| 2.2.2 | Total resources across tenant | `az graph query -q "Resources | count" --subscriptions $ALL_SUBS --first 1000` | | |
| 2.2.3 | Total App Insights instances | `az graph query -q "Resources | where type =~ 'microsoft.insights/components' | count" --subscriptions $ALL_SUBS --first 1000` | 27 | |
| 2.2.4 | Total Log Analytics Workspaces | `az graph query -q "Resources | where type =~ 'microsoft.operationalinsights/workspaces' | count" --subscriptions $ALL_SUBS --first 1000` | 26 | |
| 2.2.5 | Total alert rules (all types) | See 2.1.5 | 216 | |
| 2.2.6 | Subscriptions without any monitoring | Cross-reference results | | |

---

## 3. Subscription Inventory

### 3.1 Resource Count Summary

> ⚠️ **Remember**: Always include `--subscriptions $ALL_SUBS` to query all subscriptions!

```bash
# All-in-one summary across ALL subscriptions with resource names
az graph query -q "
Resources
| where type in~ (
    'microsoft.web/sites',
    'microsoft.insights/components',
    'microsoft.operationalinsights/workspaces',
    'microsoft.insights/actiongroups',
    'microsoft.insights/metricalerts',
    'microsoft.insights/scheduledqueryrules'
)
| extend ResourceType = case(
    type =~ 'microsoft.web/sites', 'App Service',
    type =~ 'microsoft.insights/components', 'Application Insights',
    type =~ 'microsoft.operationalinsights/workspaces', 'Log Analytics Workspace',
    type =~ 'microsoft.insights/actiongroups', 'Action Group',
    type =~ 'microsoft.insights/metricalerts', 'Metric Alert',
    type =~ 'microsoft.insights/scheduledqueryrules', 'Scheduled Query Alert',
    type)
| summarize Total=count() by ResourceType
| order by Total desc
" --subscriptions $ALL_SUBS --first 1000 --query "data" -o table
```

**Expected Output:**

| ResourceType | Total |
|--------------|-------|
| Metric Alert | 211 |
| App Service | 72 |
| Application Insights | 27 |
| Log Analytics Workspace | 26 |
| Action Group | 10 |
| Scheduled Query Alert | 5 |

### 3.2 Inventory Checklist

> 💡 **Tip**: Always use `=~` for case-insensitive type matching and `--first 1000` to get all results!

| # | Check | Command (Resource Graph Preferred) | Finding | Score |
|---|-------|---------|---------|-------|
| 3.2.1 | App Services by type (Web/Function/API) | See detailed query below | | |
| 3.2.2 | Total App Insights instances | `az graph query -q "Resources | where type =~ 'microsoft.insights/components' | count" --subscriptions $ALL_SUBS --first 1000` | | |
| 3.2.3 | Total LAW instances | `az graph query -q "Resources | where type =~ 'microsoft.operationalinsights/workspaces' | count" --subscriptions $ALL_SUBS --first 1000` | | |
| 3.2.4 | App Services WITHOUT App Insights | See query below | | |
| 3.2.5 | Ratio: App Insights to App Services | Calculate from above | | |

**Query: App Services by Type (Web App, Function App, API App):**

```bash
# IMPORTANT: Use =~ (case-insensitive) and --first 1000 for complete results!
# Breakdown of all App Services across tenant by type
az graph query -q "Resources 
| where type =~ 'microsoft.web/sites'
| extend appType = case(
    kind contains 'functionapp', 'Function App',
    kind contains 'api', 'API App',
    'Web App')
| summarize Total=count() by appType
| order by Total desc" --subscriptions $ALL_SUBS --first 1000 --query "data" -o table

# Detailed breakdown by subscription AND type
az graph query -q "Resources 
| where type =~ 'microsoft.web/sites'
| extend appType = case(
    kind contains 'functionapp', 'Function App',
    kind contains 'api', 'API App',
    'Web App')
| summarize Total=count() by subscriptionId, appType
| order by subscriptionId, Total desc" --subscriptions $ALL_SUBS --first 1000 --query "data" -o table
```

---

## 4. Monitoring Strategy Assessment

### 4.1 Architecture Pattern Check

| # | Check | Expected | Finding | Score (0-3) |
|---|-------|----------|---------|-------------|
| 4.1.1 | Single LAW per environment? | Yes | | |
| 4.1.2 | Workspace-based App Insights? | Yes (not classic) | | |
| 4.1.3 | All App Insights → same LAW? | Yes (per env) | | |
| 4.1.4 | Centralized vs distributed LAW? | Document pattern | | |
| 4.1.5 | Cross-subscription LAW strategy? | Document | | |

**Assessment Commands:**

```bash
# App Insights inventory across ALL subscriptions
az graph query -q "
Resources
| where type =~ 'microsoft.insights/components'
| project name, subscriptionId, resourceGroup, location,
          ingestionMode=properties.IngestionMode,
          workspaceId=properties.WorkspaceResourceId
| order by subscriptionId, name
" --subscriptions $ALL_SUBS --first 1000 --query "data" -o table
```

> ✅ **Note**: No Classic App Insights found in audit scope. All instances are workspace-based.

### 4.2 Strategy Scoring

| Pattern | Score | Description |
|---------|-------|-------------|
| ✅ Workspace-based, unified LAW | 3 | Best practice |
| ⚠️ Workspace-based, multiple LAWs | 2 | Acceptable, may complicate queries |
| ❌ No App Insights deployed | 0 | Critical - deploy immediately |

---

## 5. Naming Conventions Audit

### 5.1 Expected Naming Patterns

| Resource Type | Expected Pattern | Example |
|---------------|------------------|---------|
| Resource Group | `rg-{workload}-{env}-{region}` | `rg-orders-prod-weu` |
| App Service | `app-{workload}-{env}-{region}` | `app-orders-prod-weu` |
| Function App | `func-{workload}-{env}-{region}` | `func-orders-prod-weu` |
| App Service Plan | `asp-{workload}-{env}-{region}` | `asp-orders-prod-weu` |
| Application Insights | `appi-{component}-{env}-{region}` | `appi-orders-prod-weu` |
| Log Analytics | `law-{workload}-{env}-{region}` | `law-orders-prod-weu` |
| Action Group | `ag-{purpose}-{env}-{workload}` | `ag-mon-prod-orders` |
| Alert Rule | `alrt-{env}-{workload}-{signal}` | `alrt-prod-orders-5xx` |

### 5.2 Naming Compliance Checks

```bash
# Check naming compliance across ALL subscriptions using Resource Graph

# App Services naming compliance
az graph query -q "
Resources
| where type =~ 'microsoft.web/sites'
| extend isCompliant = name startswith 'app-' or name startswith 'web-' or name startswith 'func-' or name startswith 'wa' or name startswith 'ws' or name startswith 'fn'
| summarize Compliant=countif(isCompliant), NonCompliant=countif(not(isCompliant)) by subscriptionId
" --subscriptions $ALL_SUBS --first 1000 --query "data" -o table

# Log Analytics Workspace naming compliance
az graph query -q "
Resources
| where type =~ 'microsoft.operationalinsights/workspaces'
| extend isCompliant = name startswith 'law-' or name startswith 'log-' or name startswith 'lw'
| summarize Compliant=countif(isCompliant), NonCompliant=countif(not(isCompliant)) by subscriptionId
" --subscriptions $ALL_SUBS --first 1000 --query "data" -o table
```

### 5.3 Naming Audit Checklist

| # | Check | Query | Compliant | Non-Compliant | Score |
|---|-------|-------|-----------|---------------|-------|
| 5.3.1 | Resource Groups follow pattern | See above | | | |
| 5.3.2 | App Services follow pattern | See above | | | |
| 5.3.3 | Function Apps follow pattern | See above | | | |
| 5.3.4 | App Insights follow pattern | See above | | | |
| 5.3.5 | LAW follow pattern | See above | | | |
| 5.3.6 | Action Groups follow pattern | | | | |
| 5.3.7 | Alert Rules follow pattern | | | | |
| 5.3.8 | Environment indicated in name | | | | |
| 5.3.9 | Region/location suffix present | | | | |
| 5.3.10 | Consistent casing (lowercase) | | | | |

---

## 6. Tagging Compliance Audit

### 6.1 Required Tags Definition

| Tag Name | Purpose | Required | Example |
|----------|---------|----------|---------|
| `env` | Environment identifier | ✅ Yes | `dev`, `staging`, `prod` |
| `workload` | Application/workload name | ✅ Yes | `orders-api` |
| `owner` | Team or individual owner | ✅ Yes | `platform-team` |
| `costCenter` | Billing/chargeback code | ✅ Yes | `CC-12345` |
| `createdBy` | Creator identifier | ⚠️ Recommended | `terraform`, `bicep` |
| `createdDate` | Creation timestamp | ⚠️ Recommended | `2024-01-15` |
| `supportContact` | Support team/email | ⚠️ Recommended | `ops@company.com` |

### 6.2 Tag Compliance Commands

```bash
# Resources missing 'env' tag across ALL subscriptions
az graph query -q "
Resources
| where isnull(tags['env']) or tags['env'] == ''
| summarize Total=count() by subscriptionId, type
| order by Total desc
" --subscriptions $ALL_SUBS --first 1000 --query "data" -o table

# Resources missing multiple required tags (summary by subscription)
az graph query -q "
Resources
| extend 
    missingEnv = isnull(tags['env']),
    missingOwner = isnull(tags['owner']),
    missingWorkload = isnull(tags['workload']),
    missingCostCenter = isnull(tags['costCenter'])
| where missingEnv or missingOwner or missingWorkload or missingCostCenter
| summarize 
    MissingEnv=countif(missingEnv),
    MissingOwner=countif(missingOwner),
    MissingWorkload=countif(missingWorkload),
    MissingCostCenter=countif(missingCostCenter)
    by subscriptionId
" --subscriptions $ALL_SUBS --first 1000 --query "data" -o table

# Export to CSV (uses audit script)
# Results in audit-*/summary/missing-tag-*.csv
./scripts/multi-subscription-audit.sh
```

### 6.3 Tag Audit Checklist

| # | Check | Command | Total | Missing | % Compliant | Score |
|---|-------|---------|-------|---------|-------------|-------|
| 6.3.1 | Resources with `env` tag | | | | | |
| 6.3.2 | Resources with `workload` tag | | | | | |
| 6.3.3 | Resources with `owner` tag | | | | | |
| 6.3.4 | Resources with `costCenter` tag | | | | | |
| 6.3.5 | App Services fully tagged | | | | | |
| 6.3.6 | App Insights fully tagged | | | | | |
| 6.3.7 | LAW fully tagged | | | | | |
| 6.3.8 | Consistent tag values (no typos) | | | | | |
| 6.3.9 | Environment values standardized | | | | | |
| 6.3.10 | Azure Policy for tags exists | | | | | |

### 6.4 Tag Policy Check

```bash
# Check if tag enforcement policies exist
az policy assignment list --query "[?contains(displayName, 'tag') || contains(displayName, 'Tag')].{
  Name:name,
  DisplayName:displayName,
  Scope:scope,
  EnforcementMode:enforcementMode
}" -o table

# Check policy compliance state
az policy state summarize --query "{
  TotalResources:results.resourceDetails[0].totalResources,
  CompliantResources:results.resourceDetails[0].compliantResources,
  NonCompliantResources:results.resourceDetails[0].nonCompliantResources
}"
```

---

## 7. Application Insights Configuration

### 7.1 App Insights Inventory

```bash
# App Insights inventory across ALL subscriptions
az graph query -q "
Resources
| where type =~ 'microsoft.insights/components'
| project 
    name,
    subscriptionId,
    resourceGroup,
    location,
    ingestionMode=properties.IngestionMode,
    workspaceId=properties.WorkspaceResourceId,
    retentionDays=properties.RetentionInDays
| order by subscriptionId, name
" --subscriptions $ALL_SUBS --first 1000 --query "data" -o table
```

### 7.2 App Insights Audit Checklist

| # | Check | Expected | Command | Finding | Score |
|---|-------|----------|---------|---------|-------|
| 7.2.1 | Ingestion mode is LogAnalytics | `LogAnalytics` | See above | | |
| 7.2.2 | Linked to Log Analytics Workspace | Not null | | | |
| 7.2.3 | IP masking enabled (GDPR) | `true` (disableIpMasking=false) | | | |
| 7.2.4 | Retention configured | 30-90 days | | | |
| 7.2.5 | Sampling configured | Documented | | | |
| 7.2.6 | Connection string (not iKey) used | Check app settings | | | |
| 7.2.7 | Unique App Insights per component | 1:1 mapping | | | |
| 7.2.8 | Daily cap configured (cost control) | If budget limited | | | |

### 7.3 Connection String vs Instrumentation Key Analysis

> **IMPORTANT:** Microsoft deprecated InstrumentationKey-only configuration in March 2025. Apps should use Connection String.

#### Key Differences

| Aspect | InstrumentationKey (Legacy) | Connection String (Modern) |
|--------|----------------------------|---------------------------|
| **Format** | GUID only | Full string with endpoints |
| **Regional Ingestion** | ❌ Global endpoint only | ✅ Regional endpoints |
| **Private Link (AMPLS)** | ❌ Not supported | ✅ Required |
| **AAD Authentication** | ❌ Not supported | ✅ Supported |
| **Future Support** | ⚠️ Deprecated | ✅ Recommended |

#### Migration Impact
- **Low risk**: Just configuration change, no code changes required
- **Recommendation**: Migrate all apps from `APPINSIGHTS_INSTRUMENTATIONKEY` to `APPLICATIONINSIGHTS_CONNECTION_STRING`

#### Check Commands (Requires Website Contributor Role)

```bash
# NOTE: These commands require 'Microsoft.Web/sites/config/list/action' permission
# If you only have Reader role, ask the app team to run these or request elevated access

# Check a specific app's App Insights configuration
az webapp config appsettings list -n "<app-name>" -g "<resource-group>" \
  --query "[?contains(name, 'APPINSIGHTS') || contains(name, 'APPLICATIONINSIGHTS')].{
    Setting:name,
    HasValue:value!=null
  }" -o table

# Bulk check all apps (requires permissions)
for sub in $ALL_SUBS; do
  echo "=== Subscription: ${sub:0:8}... ==="
  az webapp list --subscription "$sub" --query "[].{name:name,rg:resourceGroup}" -o tsv 2>/dev/null | while read name rg; do
    settings=$(az webapp config appsettings list -n "$name" -g "$rg" --subscription "$sub" \
      --query "[?name=='APPINSIGHTS_INSTRUMENTATIONKEY' || name=='APPLICATIONINSIGHTS_CONNECTION_STRING'].name" -o tsv 2>/dev/null | tr '\n' ',')
    
    if [[ "$settings" == *"CONNECTION_STRING"* ]] && [[ "$settings" == *"INSTRUMENTATIONKEY"* ]]; then
      echo "⚠️  BOTH: $name (has legacy + modern)"
    elif [[ "$settings" == *"CONNECTION_STRING"* ]]; then
      echo "✅ MODERN: $name"
    elif [[ "$settings" == *"INSTRUMENTATIONKEY"* ]]; then
      echo "🔴 LEGACY: $name (needs migration)"
    else
      echo "❌ NONE: $name (no App Insights)"
    fi
  done
done
```

#### Alternative: Resource Graph Query for Linked Resources

```bash
# Check which App Services have App Insights resource linked (via ARM)
# This checks the resource link, not app settings
az graph query -q "
  resources
  | where type =~ 'microsoft.web/sites'
  | extend appInsightsKey = tostring(tags['hidden-link: /app-insights-resource-id'])
  | project name, resourceGroup, subscriptionId, 
      hasAppInsightsLink = isnotempty(appInsightsKey)
  | summarize 
      total=count(),
      withLink=countif(hasAppInsightsLink == true),
      withoutLink=countif(hasAppInsightsLink == false)
" --subscriptions $ALL_SUBS --first 1000 --query "data" -o table

# Summary by subscription
az graph query -q "
  resources
  | where type =~ 'microsoft.web/sites'
  | extend hasAppInsightsLink = tags contains 'hidden-link'
  | summarize total=count(),
      linked=countif(hasAppInsightsLink == true),
      notLinked=countif(hasAppInsightsLink == false) by subscriptionId
  | order by subscriptionId
" --subscriptions $ALL_SUBS --first 1000 --query "data" -o table

# List apps WITHOUT App Insights link (priority for remediation)
az graph query -q "
  resources
  | where type =~ 'microsoft.web/sites'
  | where not(tags contains 'hidden-link')
  | project name, resourceGroup, subscriptionId, kind
  | order by subscriptionId, name
" --subscriptions $ALL_SUBS --first 1000 --query "data" -o table
```

#### 7.3.1 Instrumentation Key Migration Checklist

| # | Check | Status |
|---|-------|--------|
| 7.3.1.1 | Identify apps using only APPINSIGHTS_INSTRUMENTATIONKEY | |
| 7.3.1.2 | Get Connection String from linked App Insights | |
| 7.3.1.3 | Add APPLICATIONINSIGHTS_CONNECTION_STRING setting | |
| 7.3.1.4 | Test telemetry flows correctly | |
| 7.3.1.5 | Remove APPINSIGHTS_INSTRUMENTATIONKEY (optional) | |

### 7.4 App Insights to App Service Mapping

```bash
# For each App Service, verify App Insights connection
az webapp list --query "[].{Name:name, ResourceGroup:resourceGroup}" -o tsv | while read name rg; do
  CONN_STRING=$(az webapp config appsettings list -n "$name" -g "$rg" \
    --query "[?name=='APPLICATIONINSIGHTS_CONNECTION_STRING'].value" -o tsv)
  if [ -z "$CONN_STRING" ]; then
    echo "❌ MISSING: $name"
  else
    echo "✅ OK: $name"
  fi
done
```

---

## 8. Log Analytics Workspace Assessment

### 8.1 LAW Inventory

```bash
# LAW inventory across ALL subscriptions
az graph query -q "
Resources
| where type =~ 'microsoft.operationalinsights/workspaces'
| project 
    name,
    subscriptionId,
    resourceGroup,
    location,
    sku=properties.sku.name,
    retentionDays=properties.retentionInDays,
    dailyCapGb=properties.workspaceCapping.dailyQuotaGb
| order by subscriptionId, name
" --subscriptions $ALL_SUBS --first 1000 --query "data" -o table
```

### 8.2 LAW Audit Checklist

| # | Check | Expected | Finding | Score |
|---|-------|----------|---------|-------|
| 8.2.1 | SKU is PerGB2018 (pay-as-you-go) | `PerGB2018` | | |
| 8.2.2 | Retention appropriate for env | Dev: 30d, Prod: 90d+ | | |
| 8.2.3 | Daily cap configured (cost control) | If budget limited | | |
| 8.2.4 | One LAW per environment | Best practice | | |
| 8.2.5 | Cross-region LAW strategy documented | | | |
| 8.2.6 | Data export configured (if needed) | | | |
| 8.2.7 | Private link (if required) | | | |

### 8.3 LAW Data Volume Analysis

```bash
# Check data ingestion volume per table (requires Log Analytics Reader)
LAW_NAME="<law-name>"
LAW_RG="<resource-group>"

az monitor log-analytics query -w $(az monitor log-analytics workspace show -n $LAW_NAME -g $LAW_RG --query customerId -o tsv) \
  --analytics-query "
    Usage
    | where TimeGenerated > ago(30d)
    | summarize TotalGB = sum(Quantity) / 1024 by DataType
    | order by TotalGB desc
    | take 10
  " -o table
```

### 8.4 Per-Table Retention Check

```bash
# List tables with custom retention
az monitor log-analytics workspace table list \
  --resource-group $LAW_RG \
  --workspace-name $LAW_NAME \
  --query "[?retentionInDays!=null].{
    Table:name,
    RetentionDays:retentionInDays,
    TotalRetention:totalRetentionInDays,
    ArchiveRetention:archiveRetentionInDays
  }" -o table
```

---

## 9. Distributed Tracing & Correlation

### 9.1 Tracing Configuration Checklist

| # | Check | Expected | How to Verify | Finding | Score |
|---|-------|----------|---------------|---------|-------|
| 9.1.1 | W3C TraceContext enabled | Default in modern SDKs | Check SDK version | | |
| 9.1.2 | `cloud_RoleName` set per service | Unique per component | KQL query | | |
| 9.1.3 | `cloud_RoleInstance` populated | Auto or configured | KQL query | | |
| 9.1.4 | Operation correlation working | Traces span services | KQL query | | |
| 9.1.5 | HTTP header propagation enabled | `traceparent` header | Test request | | |
| 9.1.6 | SDK version is current | Check for updates | | | |

### 9.2 Verify cloud_RoleName Configuration

```kql
// Run in Log Analytics or App Insights Logs
// Check if cloud_RoleName is properly set

requests
| where timestamp > ago(24h)
| summarize RequestCount = count() by cloud_RoleName
| order by RequestCount desc

// ISSUE: If cloud_RoleName is empty or generic, services cannot be distinguished
```

### 9.3 Verify Trace Correlation

```kql
// Check if traces are properly correlated across services
requests
| where timestamp > ago(1h)
| where isnotempty(operation_Id)
| summarize 
    ServiceCount = dcount(cloud_RoleName),
    Services = make_set(cloud_RoleName)
    by operation_Id
| where ServiceCount > 1
| take 10

// GOOD: Should see operation_Id spanning multiple services
// BAD: If ServiceCount is always 1, correlation may not be working
```

### 9.4 Check Dependency Tracking

```kql
// Verify dependencies are being tracked
dependencies
| where timestamp > ago(24h)
| summarize 
    Count = count(),
    AvgDuration = avg(duration),
    FailureRate = countif(success == false) * 100.0 / count()
    by type, target
| order by Count desc
| take 20

// Should see: HTTP, SQL, Azure Blob, etc.
// ISSUE: If empty, auto-instrumentation may not be working
```

### 9.5 SDK Version Audit

```bash
# Check OpenTelemetry / App Insights SDK versions in App Services
az webapp list --query "[].{Name:name, ResourceGroup:resourceGroup}" -o tsv | while read name rg; do
  echo "=== $name ==="
  az webapp config appsettings list -n "$name" -g "$rg" \
    --query "[?contains(name, 'OTEL') || contains(name, 'APPINSIGHTS') || contains(name, 'APPLICATIONINSIGHTS')].{Setting:name, Value:value}" -o table
done
```

---

## 10. Sampling Configuration

### 10.1 Sampling Strategy Assessment

| # | Check | Expected | Finding | Score |
|---|-------|----------|---------|-------|
| 10.1.1 | Sampling strategy documented | Yes | | |
| 10.1.2 | Dev environment sampling | 100% (no sampling) | | |
| 10.1.3 | Prod environment sampling | 10-25% typical | | |
| 10.1.4 | Sampling type (fixed vs adaptive) | Document | | |
| 10.1.5 | Critical transactions excluded from sampling | If applicable | | |

### 10.2 Check Sampling Configuration

```bash
# Check OTEL sampling configuration
az webapp config appsettings list -n <app-name> -g <rg> \
  --query "[?contains(name, 'SAMPLING') || contains(name, 'SAMPLER')].{Setting:name, Value:value}" -o table

# Check App Insights sampling
az monitor app-insights component show --app <appi-name> -g <rg> \
  --query "{SamplingPercentage:samplingPercentage}"
```

### 10.3 Verify Sampling Impact

```kql
// Check if sampling is affecting data
// Compare itemCount vs actual rows

requests
| where timestamp > ago(1h)
| summarize 
    ActualRows = count(),
    EstimatedTotal = sum(itemCount),
    SamplingRatio = sum(itemCount) / count()
| extend SamplingActive = SamplingRatio > 1.1

// SamplingRatio > 1 indicates sampling is active
// Example: Ratio of 10 means ~10% sampling
```

### 10.4 Sampling Audit Checklist

| Environment | Expected Rate | Actual Rate | itemCount Check | Score |
|-------------|---------------|-------------|-----------------|-------|
| Development | 100% | | | |
| Staging | 50-100% | | | |
| Production | 10-25% | | | |

---

## 11. Retention & Cost Optimization

### 11.1 Retention Configuration Audit

| # | Check | Dev Expected | Prod Expected | Finding | Score |
|---|-------|--------------|---------------|---------|-------|
| 11.1.1 | LAW default retention | 30 days | 90 days | | |
| 11.1.2 | App Insights retention | 30 days | 90 days | | |
| 11.1.3 | Per-table retention configured | Optional | Yes | | |
| 11.1.4 | Archive tier used | No | Optional | | |
| 11.1.5 | Data export for long-term | No | If compliance needed | | |

### 11.2 Cost Analysis Queries

```kql
// Estimate monthly cost based on data volume
Usage
| where TimeGenerated > ago(30d)
| summarize TotalGB = sum(Quantity) / 1024
| extend EstimatedMonthlyCost_USD = TotalGB * 2.30

// Cost breakdown by data type
Usage
| where TimeGenerated > ago(30d)
| summarize GB = sum(Quantity) / 1024 by DataType
| extend Cost_USD = GB * 2.30
| order by Cost_USD desc
```

### 11.3 High-Volume Table Identification

```kql
// Identify tables consuming most storage
Usage
| where TimeGenerated > ago(7d)
| summarize 
    DailyGB = sum(Quantity) / 1024 / 7,
    MonthlyProjection = sum(Quantity) / 1024 / 7 * 30
    by DataType
| where MonthlyProjection > 1
| order by MonthlyProjection desc
```

### 11.4 Cost Optimization Checklist

| # | Optimization | Status | Potential Savings | Priority |
|---|--------------|--------|-------------------|----------|
| 11.4.1 | Reduce verbose logging | | | |
| 11.4.2 | Implement sampling (prod) | | | |
| 11.4.3 | Reduce retention where possible | | | |
| 11.4.4 | Archive cold data | | | |
| 11.4.5 | Remove unused App Insights | | | |
| 11.4.6 | Consolidate LAWs | | | |
| 11.4.7 | Filter unnecessary telemetry | | | |
| 11.4.8 | Use Basic logs tier for verbose data | | | |

### 11.5 Budget Alert Check

```bash
# Check if budget alerts exist
az consumption budget list --query "[].{
  Name:name,
  Amount:amount,
  TimeGrain:timeGrain,
  Category:category
}" -o table
```

---

## 12. Alerting & Action Groups

### 12.1 Action Group Inventory

```bash
# Action Groups across ALL subscriptions
az graph query -q "
Resources
| where type =~ 'microsoft.insights/actiongroups'
| project 
    name,
    subscriptionId,
    resourceGroup,
    enabled=properties.enabled,
    emailCount=array_length(properties.emailReceivers),
    smsCount=array_length(properties.smsReceivers),
    webhookCount=array_length(properties.webhookReceivers)
" --subscriptions $ALL_SUBS --first 1000 --query "data" -o table
```

### 12.2 Alert Rules Inventory

```bash
# All alert rules across ALL subscriptions (summary by type)
az graph query -q "
Resources
| where type in~ ('microsoft.insights/metricalerts', 'microsoft.insights/scheduledqueryrules', 'microsoft.insights/activitylogalerts')
| extend alertType = case(
    type =~ 'microsoft.insights/metricalerts', 'Metric Alert',
    type =~ 'microsoft.insights/scheduledqueryrules', 'Scheduled Query Alert',
    'Activity Log Alert')
| summarize Total=count() by subscriptionId, alertType
" --subscriptions $ALL_SUBS --first 1000 --query "data" -o table

# Detailed alert rules with enabled status
az graph query -q "
Resources
| where type in~ ('microsoft.insights/metricalerts', 'microsoft.insights/scheduledqueryrules')
| project 
    name,
    subscriptionId,
    resourceGroup,
    type,
    severity=properties.severity,
    enabled=properties.enabled
| order by subscriptionId, type, name
" --subscriptions $ALL_SUBS --first 1000 --query "data" -o table
```

### 12.3 Alert Coverage Audit

| # | Check | Expected | Finding | Score |
|---|-------|----------|---------|-------|
| 12.3.1 | Action Group exists | At least 1 per env | | |
| 12.3.2 | Email receivers configured | Yes | | |
| 12.3.3 | HTTP 5xx alert exists | Yes, per app | | |
| 12.3.4 | Response time alert exists | Yes, per app | | |
| 12.3.5 | Exception alert exists | Yes, per app | | |
| 12.3.6 | Availability alert exists | For prod apps | | |
| 12.3.7 | CPU/Memory alerts (App Service Plan) | Optional | | |
| 12.3.8 | Dependency failure alerts | For prod | | |
| 12.3.9 | Auto-mitigate enabled | Yes | | |
| 12.3.10 | Alert severity appropriate | Prod=0-1, Dev=2-3 | | |

### 12.4 Alert Best Practices Check

```bash
# Check for proper alert configuration
az monitor scheduled-query list --query "[].{
  Name:name,
  Severity:severity,
  EvaluationFrequency:evaluationFrequency,
  WindowSize:windowSize,
  AutoMitigate:autoMitigate,
  ActionGroupCount:length(actions.actionGroups)
}" -o table 2>/dev/null
```

### 12.5 Missing Alerts Detection

```kql
// Find App Services without corresponding alerts
// Run this after exporting alert scopes

// Check if 5xx errors are occurring but no alert exists
requests
| where timestamp > ago(24h)
| where resultCode startswith "5"
| summarize 
    ErrorCount = count(),
    LastError = max(timestamp)
    by cloud_RoleName, appId
| where ErrorCount > 10
```

---

## 13. Diagnostic Settings

### 13.1 Diagnostic Settings Inventory

> ⚠️ **Note**: Diagnostic Settings are extension resources and not directly queryable via Resource Graph. Use the subscription-level commands below.

```bash
# Quick check: Count App Services per subscription (for comparison)
az graph query -q "
Resources
| where type =~ 'microsoft.web/sites'
| summarize AppCount=count() by subscriptionId
" --subscriptions $ALL_SUBS --first 1000 --query "data" -o table

# For each subscription, check diagnostic settings on App Services
# This requires iterating through subscriptions (run during audit)
for SUB_ID in $ALL_SUBS; do
  echo "=== Subscription: $SUB_ID ==="
  az account set --subscription "$SUB_ID"
  
  # List App Services with diagnostic settings status
  az webapp list --query "[].{Name:name, RG:resourceGroup, Id:id}" -o tsv 2>/dev/null | while IFS=$'\t' read -r name rg id; do
    DIAG_COUNT=$(az monitor diagnostic-settings list --resource "$id" --query "length(@)" -o tsv 2>/dev/null || echo "0")
    if [ "$DIAG_COUNT" -eq "0" ]; then
      echo "❌ NO DIAG: $name"
    else
      echo "✅ HAS DIAG: $name ($DIAG_COUNT settings)"
    fi
  done
done
```

**Quick summary approach (faster):**
```bash
# Count total App Services
TOTAL_APPS=$(az graph query -q "Resources | where type =~ 'microsoft.web/sites' | count" --subscriptions $ALL_SUBS --first 1000 --query "data[0].Count" -o tsv)
echo "Total App Services: $TOTAL_APPS"
echo "Review a sample of apps in each subscription for diagnostic settings"
```

### 13.2 Diagnostic Settings Checklist

| # | Check | Expected | Finding | Score |
|---|-------|----------|---------|-------|
| 13.2.1 | App Service diagnostic settings exist | Yes | | |
| 13.2.2 | Logs sent to LAW | Yes | | |
| 13.2.3 | AppServiceHTTPLogs enabled | Yes | | |
| 13.2.4 | AppServiceConsoleLogs enabled | Optional | | |
| 13.2.5 | AppServiceAppLogs enabled | Yes | | |
| 13.2.6 | AppServicePlatformLogs enabled | Yes | | |
| 13.2.7 | Metrics sent to LAW | Optional | | |
| 13.2.8 | Retention configured | Match LAW | | |

### 13.3 Recommended Diagnostic Categories

| Category | Purpose | Recommended |
|----------|---------|-------------|
| AppServiceHTTPLogs | HTTP request/response logs | ✅ Yes |
| AppServiceConsoleLogs | stdout/stderr from container | ⚠️ Verbose |
| AppServiceAppLogs | Application logs | ✅ Yes |
| AppServiceAuditLogs | Authentication/authorization | ✅ Yes |
| AppServiceIPSecAuditLogs | IP security audit | ⚠️ If IP restrictions |
| AppServicePlatformLogs | Platform events | ✅ Yes |
| AppServiceFileAuditLogs | File system changes | ⚠️ If needed |

---

## 14. RBAC & Security

### 14.1 Monitoring RBAC Roles

```bash
# Role Assignments across ALL subscriptions (Resource Graph)
az graph query -q "
AuthorizationResources
| where type =~ 'microsoft.authorization/roleassignments'
| extend principalType = tostring(properties.principalType)
| summarize AssignmentCount=count() by subscriptionId, principalType
| order by AssignmentCount desc
" --subscriptions $ALL_SUBS --first 1000 --query "data" -o table

# Detailed role assignments (sample)
az graph query -q "
AuthorizationResources
| where type =~ 'microsoft.authorization/roleassignments'
| extend principalId = tostring(properties.principalId)
| extend principalType = tostring(properties.principalType)
| extend roleDefinitionId = tostring(properties.roleDefinitionId)
| extend scope = tostring(properties.scope)
| project subscriptionId, principalType, roleDefinitionId, scope
| take 50
" --subscriptions $ALL_SUBS --first 1000 --query "data" -o table

# List monitoring-related role definitions (single subscription)
az role definition list --query "[?contains(roleName, 'Monitoring') || contains(roleName, 'Log Analytics')].{Name:roleName, Type:roleType}" -o table
```

> 💡 **Note**: Use `AuthorizationResources` table for cross-subscription role assignment queries. Role definitions can be queried using `az role definition list`.

### 14.2 RBAC Audit Checklist

| # | Check | Expected | Finding | Score |
|---|-------|----------|---------|-------|
| 14.2.1 | Monitoring Reader role assigned | For read-only users | | |
| 14.2.2 | Monitoring Contributor role assigned | For ops team | | |
| 14.2.3 | Log Analytics Reader assigned | For query access | | |
| 14.2.4 | Log Analytics Contributor assigned | For LAW admins | | |
| 14.2.5 | No Owner/Contributor for monitoring only | Least privilege | | |
| 14.2.6 | Service principals have minimal scope | | | |
| 14.2.7 | PIM used for privileged roles | If available | | |

### 14.3 Data Privacy Check

| # | Check | Expected | Finding | Score |
|---|-------|----------|---------|-------|
| 14.3.1 | IP masking enabled in App Insights | Yes (GDPR) | | |
| 14.3.2 | PII not logged (spot check) | No PII in logs | | |
| 14.3.3 | Data residency (LAW location) | Same as data region | | |
| 14.3.4 | Customer-managed keys (if required) | Document | | |
| 14.3.5 | Private endpoints (if required) | Document | | |

### 14.4 Check IP Masking

```bash
# Verify IP masking is enabled (disableIpMasking should be false/null)
az monitor app-insights component list --query "[].{
  Name:name,
  DisableIpMasking:disableIpMasking
}" -o table

# WARNING: If disableIpMasking is true, real IPs are stored (GDPR concern)
```

---

## 15. Azure Monitor Configuration

### 15.1 Data Collection Rules (DCR) Inventory

> **Note:** Data Collection Rules are the modern way to configure data collection with Azure Monitor Agent. If no DCRs exist, VMs may be using legacy agents or have no monitoring.

```bash
# List all Data Collection Rules
az graph query -q "
  resources
  | where type == 'microsoft.insights/datacollectionrules'
  | project name, resourceGroup, subscriptionId, location
" --subscriptions $ALL_SUBS --first 1000 --query "data" -o table

# Count DCRs by subscription
az graph query -q "
  resources
  | where type == 'microsoft.insights/datacollectionrules'
  | summarize count() by subscriptionId
" --subscriptions $ALL_SUBS --first 1000 --query "data" -o table
```

### 15.2 Data Collection Endpoints

> **Note:** Data Collection Endpoints are required for private link scenarios and some DCR configurations.

```bash
# List Data Collection Endpoints
az graph query -q "
  resources
  | where type == 'microsoft.insights/datacollectionendpoints'
  | project name, resourceGroup, subscriptionId, location
" --subscriptions $ALL_SUBS --first 1000 --query "data" -o table
```

### 15.3 Autoscale Settings

> **Important:** Production App Service Plans should have autoscale configured. Disabled autoscale settings may indicate incomplete setup.

```bash
# List all Autoscale Settings with status
az graph query -q "
  resources
  | where type == 'microsoft.insights/autoscalesettings'
  | project name, resourceGroup, subscriptionId, location,
      targetResourceUri=properties.targetResourceUri,
      enabled=properties.enabled
" --subscriptions $ALL_SUBS --first 1000 --query "data" -o table

# Summary: Count enabled vs disabled autoscale
az graph query -q "
  resources
  | where type == 'microsoft.insights/autoscalesettings'
  | summarize total=count(),
      enabled=countif(properties.enabled == true),
      disabled=countif(properties.enabled == false)
" --subscriptions $ALL_SUBS --first 1000 --query "data" -o table

# Find App Service Plans without autoscale
az graph query -q "
  resources
  | where type == 'microsoft.web/serverfarms'
  | where sku.tier in~ ('Standard', 'Premium', 'PremiumV2', 'PremiumV3')
  | project planId=tolower(id), name, resourceGroup, subscriptionId, sku=sku.name
  | join kind=leftouter (
      resources
      | where type == 'microsoft.insights/autoscalesettings'
      | project planId=tolower(properties.targetResourceUri), autoscaleName=name
  ) on planId
  | where isempty(autoscaleName)
  | project name, resourceGroup, subscriptionId, sku
" --subscriptions $ALL_SUBS --first 1000 --query "data" -o table
```

### 15.4 Service Health Alerts

> **Critical:** Every subscription should have Service Health alerts configured to receive proactive notifications about Azure outages.

```bash
# List Service Health Alerts
az graph query -q "
  resources
  | where type == 'microsoft.insights/activitylogalerts'
  | where properties.condition.allOf[0].equals == 'ServiceHealth'
  | project name, resourceGroup, subscriptionId, enabled=properties.enabled
" --subscriptions $ALL_SUBS --first 1000 --query "data" -o table

# Find subscriptions WITHOUT Service Health alerts
az graph query -q "
  resourcecontainers
  | where type == 'microsoft.resources/subscriptions'
  | project subscriptionId, subscriptionName=name
  | join kind=leftouter (
      resources
      | where type == 'microsoft.insights/activitylogalerts'
      | where properties.condition.allOf[0].equals == 'ServiceHealth'
      | distinct subscriptionId
      | project subscriptionId, hasHealthAlert=true
  ) on subscriptionId
  | where isempty(hasHealthAlert)
  | project subscriptionName, subscriptionId
" --subscriptions $ALL_SUBS --first 1000 --query "data" -o table
```

### 15.5 VM Monitoring Agents

> **Note:** Azure Monitor Agent (AMA) is the recommended agent, replacing legacy MMA/OMS agents. VMs without monitoring agents have no telemetry collection.

```bash
# List VMs with Azure Monitor Agent (AMA)
az graph query -q "
  resources
  | where type == 'microsoft.compute/virtualmachines/extensions'
  | where properties.publisher == 'Microsoft.Azure.Monitor'
  | project extensionName=name, vmName=split(id, '/')[8],
      resourceGroup, subscriptionId, extensionType=properties.type
" --subscriptions $ALL_SUBS --first 1000 --query "data" -o table

# List VMs with Legacy MMA/OMS Agent
az graph query -q "
  resources
  | where type == 'microsoft.compute/virtualmachines/extensions'
  | where properties.publisher == 'Microsoft.EnterpriseCloud.Monitoring'
  | project extensionName=name, vmName=split(id, '/')[8],
      resourceGroup, subscriptionId, extensionType=properties.type
" --subscriptions $ALL_SUBS --first 1000 --query "data" -o table

# Find VMs with NO monitoring agent (neither AMA nor MMA)
az graph query -q "
  resources
  | where type == 'microsoft.compute/virtualmachines'
  | project vmId=tolower(id), vmName=name, resourceGroup, subscriptionId
  | join kind=leftouter (
      resources
      | where type == 'microsoft.compute/virtualmachines/extensions'
      | where properties.publisher in~ ('Microsoft.Azure.Monitor', 'Microsoft.EnterpriseCloud.Monitoring')
      | project vmId=tolower(substring(id, 0, indexof(id, '/extensions/'))), hasAgent=true
  ) on vmId
  | where isempty(hasAgent)
  | project vmName, resourceGroup, subscriptionId
" --subscriptions $ALL_SUBS --first 1000 --query "data" -o table
```

### 15.6 Azure Monitor Private Link Scope (AMPLS)

> **Note:** Private Link Scopes enable private network connectivity for Azure Monitor. Required for secure/isolated environments.

```bash
# List Private Link Scopes
az graph query -q "
  resources
  | where type == 'microsoft.insights/privatelinkscopes'
  | project name, resourceGroup, subscriptionId, location
" --subscriptions $ALL_SUBS --first 1000 --query "data" -o table
```

### 15.7 Managed Prometheus & Grafana

> **Note:** For container/AKS workloads, Azure Managed Prometheus and Grafana provide integrated metrics and dashboards.

```bash
# List Azure Monitor Workspaces (Managed Prometheus) and Grafana
az graph query -q "
  resources
  | where type in~ ('microsoft.monitor/accounts', 'microsoft.dashboard/grafana')
  | project name, type, resourceGroup, subscriptionId, location
" --subscriptions $ALL_SUBS --first 1000 --query "data" -o table
```

### 15.8 Azure Monitor Configuration Checklist

| # | Check | Expected | Finding | Score |
|---|-------|----------|---------|-------|
| 15.8.1 | Data Collection Rules exist | If VMs present | | |
| 15.8.2 | Azure Monitor Agent on VMs | All VMs | | |
| 15.8.3 | No legacy MMA/OMS agents | Migrated to AMA | | |
| 15.8.4 | Autoscale on production App Service Plans | Enabled | | |
| 15.8.5 | Disabled autoscale settings reviewed | Document reason | | |
| 15.8.6 | Service Health alerts per subscription | All subscriptions | | |
| 15.8.7 | Private Link Scope (if required) | Document | | |
| 15.8.8 | Managed Prometheus/Grafana (if AKS) | If containers | | |

---

## 16. Governance & Policies

### 16.1 Azure Policy Inventory

```bash
# List relevant policies
az policy definition list --query "[?contains(displayName, 'monitor') || contains(displayName, 'diagnostic') || contains(displayName, 'log') || contains(displayName, 'insight')].{
  Name:name,
  DisplayName:displayName,
  PolicyType:policyType
}" -o table

# List policy assignments
az policy assignment list --query "[].{
  Name:name,
  DisplayName:displayName,
  Scope:scope,
  EnforcementMode:enforcementMode
}" -o table
```

### 16.2 Governance Checklist

| # | Check | Expected | Finding | Score |
|---|-------|----------|---------|-------|
| 16.2.1 | Tag enforcement policy exists | Yes | | |
| 16.2.2 | Diagnostic settings policy exists | Yes | | |
| 16.2.3 | Allowed locations policy exists | If data residency required | | |
| 16.2.4 | Policies in Audit mode (not blocking) | Document | | |
| 16.2.5 | Policy compliance monitored | Yes | | |
| 16.2.6 | Exception process documented | Yes | | |

### 16.3 Policy Compliance Summary

```bash
# Get policy compliance summary
az policy state summarize --query "{
  TotalPolicies:policyAssignments | length(@),
  TotalResources:results.resourceDetails[0].totalResources,
  Compliant:results.resourceDetails[0].compliantResources,
  NonCompliant:results.resourceDetails[0].nonCompliantResources,
  CompliancePercentage:results.resourceDetails[0].compliancePercentage
}"
```

---

## 17. Workbooks & Dashboards

### 17.1 Workbook Inventory

```bash
# List Azure Monitor Workbooks
az monitor app-insights workbook list --query "[].{
  Name:name,
  DisplayName:displayName,
  Category:category,
  ResourceGroup:resourceGroup
}" -o table 2>/dev/null
```

### 17.2 Dashboard Inventory

```bash
# List Azure Dashboards
az portal dashboard list --query "[].{
  Name:name,
  ResourceGroup:resourceGroup,
  Location:location
}" -o table 2>/dev/null
```

### 17.3 Visualization Checklist

| # | Check | Expected | Finding | Score |
|---|-------|----------|---------|-------|
| 16.3.1 | Operations workbook exists | Yes | | |
| 16.3.2 | Workbook covers all environments | Yes | | |
| 16.3.3 | Dashboard for executive view | Optional | | |
| 16.3.4 | Workbook sections: Overview | Yes | | |
| 16.3.5 | Workbook sections: Failures | Yes | | |
| 16.3.6 | Workbook sections: Performance | Yes | | |
| 16.3.7 | Workbook sections: Dependencies | Yes | | |
| 16.3.8 | Workbook sections: Alerts | Yes | | |
| 16.3.9 | Time range picker available | Yes | | |
| 16.3.10 | Environment filter available | Yes | | |

---

## 18. Scoring Matrix

### 17.1 Category Weights

| Category | Weight | Max Score |
|----------|--------|-----------|  
| 2. Multi-Subscription Discovery | 5% | 5 |
| 4. Monitoring Strategy | 15% | 15 |
| 5. Naming Conventions | 5% | 5 |
| 6. Tagging Compliance | 10% | 10 |
| 7. Application Insights | 15% | 15 |
| 8. Log Analytics | 10% | 10 |
| 9. Distributed Tracing | 15% | 15 |
| 10. Sampling | 5% | 5 |
| 11. Retention & Costs | 10% | 10 |
| 12. Alerting | 10% | 10 |
| **Total** | **100%** | **100** |

### 17.2 Scoring Guide

| Score | Rating | Description |
|-------|--------|-------------|
| 0 | ❌ Critical | Not implemented, critical gap |
| 1 | ⚠️ Major | Partially implemented, major issues |
| 2 | 🟡 Minor | Mostly implemented, minor issues |
| 3 | ✅ Good | Fully implemented, meets best practices |

### 17.3 Overall Score Card

| Category | Score | Max | % | Rating |
|----------|-------|-----|---|--------|
| Multi-Subscription Discovery | | 5 | | |
| Monitoring Strategy | | 15 | | |
| Naming Conventions | | 5 | | |
| Tagging Compliance | | 10 | | |
| Application Insights | | 15 | | |
| Log Analytics | | 10 | | |
| Distributed Tracing | | 15 | | |
| Sampling | | 5 | | |
| Retention & Costs | | 10 | | |
| Alerting | | 10 | | |
| **TOTAL** | | **100** | | |

### 17.4 Maturity Level

| Score Range | Maturity Level | Description |
|-------------|----------------|-------------|
| 0-25 | Level 1: Initial | Ad-hoc monitoring, no standards |
| 26-50 | Level 2: Developing | Basic monitoring, inconsistent |
| 51-75 | Level 3: Defined | Standards exist, partially followed |
| 76-90 | Level 4: Managed | Consistent implementation, measured |
| 91-100 | Level 5: Optimized | Best practices, continuous improvement |

---

## 19. Remediation Priorities

### 18.1 Priority Matrix

| Priority | Criteria | Timeline |
|----------|----------|----------|
| P1 - Critical | Security gaps, data loss risk, compliance violations | Immediate (1 week) |
| P2 - High | Missing core monitoring, alert gaps | Short-term (2-4 weeks) |
| P3 - Medium | Non-compliance with standards, cost inefficiencies | Medium-term (1-2 months) |
| P4 - Low | Nice-to-have improvements, optimizations | Backlog |

### 18.2 Common Findings & Remediation

| Finding | Priority | Remediation | Effort |
|---------|----------|-------------|--------|
| No alerts configured | P1 | Deploy baseline alert set | Low |
| PII in logs | P1 | Implement safe logging, purge data | High |
| Missing tags | P2 | Deploy tag policy, remediate | Low |
| No diagnostic settings | P2 | Deploy diagnostic settings | Low |
| Instrumentation key (not connection string) | P2 | Update to connection string | Low |
| High data ingestion costs | P3 | Implement sampling, filter logs | Medium |
| No workbooks/dashboards | P3 | Deploy standard workbook | Low |
| Inconsistent naming | P4 | Document standards, rename new resources | Low |
| No distributed tracing | P2 | Configure cloud_RoleName, verify correlation | Medium |

### 18.3 Remediation Tracking Template

| ID | Finding | Category | Priority | Owner | Due Date | Status |
|----|---------|----------|----------|-------|----------|--------|
| R001 | | | | | | |
| R002 | | | | | | |
| R003 | | | | | | |

---

## Appendix A: Quick Reference Commands

> 📖 **Full command reference**: See [`docs/multi-subscription-quick-commands.md`](multi-subscription-quick-commands.md)

### A.1 One-Liner Audit Commands (Resource Graph - Recommended)

> ⚠️ **CRITICAL**: Always include `--subscriptions $ALL_SUBS` to query ALL subscriptions!

```bash
# FIRST: Set the ALL_SUBS variable (required for multi-subscription queries!)
ALL_SUBS=$(az account list --query "[?state=='Enabled'].id" -o tsv)

# Count all resources by subscription (ALL subscriptions!)
az graph query -q "Resources | summarize Total=count() by subscriptionId" \
  --subscriptions $ALL_SUBS --first 1000 --query "data" -o table

# App Insights coverage summary by subscription
az graph query -q "Resources 
| where type =~ 'microsoft.insights/components' 
| summarize Total=count() by subscriptionId" \
  --subscriptions $ALL_SUBS --first 1000 --query "data" -o table

# Resources missing required tags
az graph query -q "Resources 
| where isnull(tags['env']) or isnull(tags['owner'])
| summarize Total=count() by subscriptionId, type | order by Total desc" \
  --subscriptions $ALL_SUBS --first 1000 --query "data" -o table

# All alert rules by type
az graph query -q "Resources 
| where type in~ ('microsoft.insights/metricalerts', 'microsoft.insights/scheduledqueryrules')
| summarize Total=count() by subscriptionId, type" \
  --subscriptions $ALL_SUBS --first 1000 --query "data" -o table

# LAW retention summary
az graph query -q "Resources 
| where type =~ 'microsoft.operationalinsights/workspaces'
| project name, subscriptionId, retention=properties.retentionInDays" \
  --subscriptions $ALL_SUBS --first 1000 --query "data" -o table
```

### A.2 Automated Multi-Subscription Audit (Post-Audit Export)

> 📋 **When to use**: Run the script at the end of the audit to generate JSON/CSV exports for the client deliverables.

**Prerequisites:**
- Bash (Git Bash on Windows, or Linux/macOS terminal)
- `jq` installed: `choco install jq` or download from [jqlang/jq](https://github.com/jqlang/jq/releases)

```bash
# Install jq first (Windows Git Bash)
# Option 1: choco install jq
# Option 2: curl -L -o /usr/bin/jq.exe https://github.com/jqlang/jq/releases/latest/download/jq-win64.exe

# Run the audit script
chmod +x scripts/multi-subscription-audit.sh
./scripts/multi-subscription-audit.sh

# With parallel execution for speed
PARALLEL_JOBS=10 ./scripts/multi-subscription-audit.sh
```

**Script Coverage (aligned with checklist):**

| Checklist Section | Script Function | Output File |
|-------------------|-----------------|-------------|
| 2.1 Discovery | `get_all_subscriptions()` | `subscriptions.json`, `subscriptions.csv` |
| 3.1 Resource Inventory | `audit_subscription()` | `subscriptions/*/all-resources.json` |
| 7 App Insights | `audit_subscription()` | `subscriptions/*/app-insights.json` |
| 8 LAW | `audit_subscription()`, `check_law_retention()` | `subscriptions/*/log-analytics.json`, `summary/law-retention.csv` |
| 6 Tag Compliance | `check_missing_tags()` | `summary/missing-tag-*.csv` |
| 12 Alerting | `audit_subscription()`, `check_alert_coverage()` | `subscriptions/*/metric-alerts.json`, `summary/alert-coverage.csv` |
| 15 Policies | `audit_subscription()` | `subscriptions/*/policy-assignments.json` |

**Output structure:**
```
audit-YYYYMMDD-HHMMSS/
├── AUDIT-REPORT.md             # Executive summary report
├── subscriptions.json          # Target subscriptions
├── subscriptions.csv           # Excel-ready subscription list
├── subscriptions/
│   └── <subscription-id>/
│       ├── all-resources.json
│       ├── app-services.json
│       ├── function-apps.json
│       ├── app-insights.json
│       ├── log-analytics.json
│       ├── action-groups.json
│       ├── metric-alerts.json
│       ├── scheduled-query-alerts.json
│       ├── policy-assignments.json
│       └── summary.json
└── summary/
    ├── full-audit-summary.json # Complete aggregated data
    ├── totals.json             # Grand totals
    ├── resource-counts.csv     # Excel-ready counts
    ├── law-retention.csv       # LAW retention settings
    ├── alert-coverage.csv      # Alert-to-app ratios
    ├── classic-app-insights.csv # Classic App Insights (if any)
    └── missing-tag-*.csv       # Tag compliance issues
```

**Not covered by script (use interactive queries):**
- Section 9: Distributed Tracing (KQL queries)
- Section 10: Sampling Configuration (KQL queries)
- Section 11: Cost Analysis (KQL queries against LAW Usage table)
- Section 13: Diagnostic Settings (Resource Graph query)
- Section 14: RBAC (Resource Graph query)

---

## Appendix B: KQL Queries for Deep Analysis

### B.1 Service Health Overview

```kql
// Overall application health summary
requests
| where timestamp > ago(24h)
| summarize 
    TotalRequests = count(),
    FailedRequests = countif(success == false),
    AvgDuration = avg(duration),
    P95Duration = percentile(duration, 95)
    by cloud_RoleName
| extend FailureRate = round(FailedRequests * 100.0 / TotalRequests, 2)
| order by TotalRequests desc
```

### B.2 Dependency Health

```kql
// External dependency analysis
dependencies
| where timestamp > ago(24h)
| summarize 
    Calls = count(),
    Failures = countif(success == false),
    AvgDuration = avg(duration)
    by type, target
| extend FailureRate = round(Failures * 100.0 / Calls, 2)
| where Calls > 10
| order by FailureRate desc
```

### B.3 Exception Analysis

```kql
// Top exceptions by type
exceptions
| where timestamp > ago(24h)
| summarize Count = count() by type, cloud_RoleName
| order by Count desc
| take 20
```

### B.4 Data Ingestion Volume

```kql
// Daily data volume trend
Usage
| where TimeGenerated > ago(30d)
| summarize DailyGB = sum(Quantity) / 1024 by bin(TimeGenerated, 1d), DataType
| render timechart
```

---

## Appendix C: Audit Report Template

```markdown
# Azure Monitoring Audit Report

**Client:** [Client Name]  
**Auditor:** [Your Name]  
**Date:** [Date]  
**Subscriptions Audited:** [Count]

## Executive Summary

Overall Maturity Score: **[X]/100** - [Level X: Description]

### Key Findings

1. **Critical:** [Description]
2. **High:** [Description]
3. **Medium:** [Description]

### Top Recommendations

1. [Recommendation 1]
2. [Recommendation 2]
3. [Recommendation 3]

## Detailed Findings

[Category-by-category findings]

## Remediation Roadmap

[Prioritized remediation plan]

## Appendix

[Supporting data and evidence]
```

---

*Checklist Version: 2.1 | Last Updated: February 3, 2026*  
*Script: [`multi-subscription-audit.sh`](../scripts/multi-subscription-audit.sh)*  
*Quick Commands: [`multi-subscription-quick-commands.md`](multi-subscription-quick-commands.md)*
