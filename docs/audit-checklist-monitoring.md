# Azure Monitoring Audit Checklist

> **Purpose**: Comprehensive audit checklist for assessing Azure App Services monitoring implementations  
> **Access Required**: Reader role on target subscriptions  
> **Version**: 1.0  
> **Date**: February 3, 2026

---

## Table of Contents

1. [Pre-Audit Setup](#1-pre-audit-setup)
2. [Subscription Inventory](#2-subscription-inventory)
3. [Monitoring Strategy Assessment](#3-monitoring-strategy-assessment)
4. [Naming Conventions Audit](#4-naming-conventions-audit)
5. [Tagging Compliance Audit](#5-tagging-compliance-audit)
6. [Application Insights Configuration](#6-application-insights-configuration)
7. [Log Analytics Workspace Assessment](#7-log-analytics-workspace-assessment)
8. [Distributed Tracing & Correlation](#8-distributed-tracing--correlation)
9. [Sampling Configuration](#9-sampling-configuration)
10. [Retention & Cost Optimization](#10-retention--cost-optimization)
11. [Alerting & Action Groups](#11-alerting--action-groups)
12. [Diagnostic Settings](#12-diagnostic-settings)
13. [RBAC & Security](#13-rbac--security)
14. [Governance & Policies](#14-governance--policies)
15. [Workbooks & Dashboards](#15-workbooks--dashboards)
16. [Scoring Matrix](#16-scoring-matrix)
17. [Remediation Priorities](#17-remediation-priorities)

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

## 2. Subscription Inventory

### 2.1 Resource Count Summary

For each subscription, gather resource counts:

```bash
SUBSCRIPTION_ID="<subscription-id>"
az account set --subscription $SUBSCRIPTION_ID

# Count key monitoring resources
echo "=== Subscription: $SUBSCRIPTION_ID ==="
echo "App Services: $(az webapp list --query "length(@)")"
echo "Function Apps: $(az functionapp list --query "length(@)")"
echo "Application Insights: $(az monitor app-insights component list --query "length(@)")"
echo "Log Analytics Workspaces: $(az monitor log-analytics workspace list --query "length(@)")"
echo "Action Groups: $(az monitor action-group list --query "length(@)")"
echo "Alert Rules: $(az monitor metrics alert list --query "length(@)")"
echo "Scheduled Query Rules: $(az monitor scheduled-query list --query "length(@)" 2>/dev/null || echo 'N/A')"
```

### 2.2 Inventory Checklist

| # | Check | Command | Finding | Score |
|---|-------|---------|---------|-------|
| 2.2.1 | Total App Services count | `az webapp list --query "length(@)"` | | |
| 2.2.2 | Total Function Apps count | `az functionapp list --query "length(@)"` | | |
| 2.2.3 | Total App Insights instances | `az monitor app-insights component list --query "length(@)"` | | |
| 2.2.4 | Total LAW instances | `az monitor log-analytics workspace list --query "length(@)"` | | |
| 2.2.5 | App Services WITHOUT App Insights | See query below | | |
| 2.2.6 | Ratio: App Insights to App Services | Calculate | | |

**Query: App Services without Application Insights:**

```bash
# List App Services missing APPLICATIONINSIGHTS_CONNECTION_STRING
az webapp list --query "[?!contains(keys(siteConfig.appSettings || {}), 'APPLICATIONINSIGHTS_CONNECTION_STRING')].{
  Name:name,
  ResourceGroup:resourceGroup,
  Location:location
}" -o table
```

---

## 3. Monitoring Strategy Assessment

### 3.1 Architecture Pattern Check

| # | Check | Expected | Finding | Score (0-3) |
|---|-------|----------|---------|-------------|
| 3.1.1 | Single LAW per environment? | Yes | | |
| 3.1.2 | Workspace-based App Insights? | Yes (not classic) | | |
| 3.1.3 | All App Insights → same LAW? | Yes (per env) | | |
| 3.1.4 | Centralized vs distributed LAW? | Document pattern | | |
| 3.1.5 | Cross-subscription LAW strategy? | Document | | |

**Assessment Commands:**

```bash
# Check if App Insights are workspace-based (modern) or classic
az monitor app-insights component list \
  --query "[].{
    Name:name,
    ResourceGroup:resourceGroup,
    IngestionMode:ingestionMode,
    WorkspaceId:workspaceResourceId,
    Type:kind
  }" -o table

# Identify CLASSIC App Insights (CRITICAL - should be migrated)
az monitor app-insights component list \
  --query "[?ingestionMode!='LogAnalytics'].{Name:name, ResourceGroup:resourceGroup}" -o table
```

### 3.2 Strategy Scoring

| Pattern | Score | Description |
|---------|-------|-------------|
| ✅ Workspace-based, unified LAW | 3 | Best practice |
| ⚠️ Workspace-based, multiple LAWs | 2 | Acceptable, may complicate queries |
| ❌ Mixed classic + workspace | 1 | Migration needed |
| ❌ All classic App Insights | 0 | Critical - migrate immediately |

---

## 4. Naming Conventions Audit

### 4.1 Expected Naming Patterns

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

### 4.2 Naming Compliance Checks

```bash
# Export all resource names for analysis
az resource list --query "[].{
  Name:name,
  Type:type,
  ResourceGroup:resourceGroup,
  Location:location
}" -o json > all-resources.json

# Check App Services naming compliance
az webapp list --query "[].{
  Name:name,
  Compliant:contains(name, 'app-') || contains(name, 'web-')
}" -o table

# Check Function Apps naming
az functionapp list --query "[].{
  Name:name,
  Compliant:contains(name, 'func-') || contains(name, 'fa-')
}" -o table

# Check App Insights naming
az monitor app-insights component list --query "[].{
  Name:name,
  Compliant:contains(name, 'appi-') || contains(name, 'ai-')
}" -o table

# Check LAW naming
az monitor log-analytics workspace list --query "[].{
  Name:name,
  Compliant:contains(name, 'law-') || contains(name, 'log-')
}" -o table
```

### 4.3 Naming Audit Checklist

| # | Check | Query | Compliant | Non-Compliant | Score |
|---|-------|-------|-----------|---------------|-------|
| 4.3.1 | Resource Groups follow pattern | See above | | | |
| 4.3.2 | App Services follow pattern | See above | | | |
| 4.3.3 | Function Apps follow pattern | See above | | | |
| 4.3.4 | App Insights follow pattern | See above | | | |
| 4.3.5 | LAW follow pattern | See above | | | |
| 4.3.6 | Action Groups follow pattern | | | | |
| 4.3.7 | Alert Rules follow pattern | | | | |
| 4.3.8 | Environment indicated in name | | | | |
| 4.3.9 | Region/location suffix present | | | | |
| 4.3.10 | Consistent casing (lowercase) | | | | |

---

## 5. Tagging Compliance Audit

### 5.1 Required Tags Definition

| Tag Name | Purpose | Required | Example |
|----------|---------|----------|---------|
| `env` | Environment identifier | ✅ Yes | `dev`, `staging`, `prod` |
| `workload` | Application/workload name | ✅ Yes | `orders-api` |
| `owner` | Team or individual owner | ✅ Yes | `platform-team` |
| `costCenter` | Billing/chargeback code | ✅ Yes | `CC-12345` |
| `createdBy` | Creator identifier | ⚠️ Recommended | `terraform`, `bicep` |
| `createdDate` | Creation timestamp | ⚠️ Recommended | `2024-01-15` |
| `supportContact` | Support team/email | ⚠️ Recommended | `ops@company.com` |

### 5.2 Tag Compliance Commands

```bash
# Check resources missing required tags
REQUIRED_TAGS=("env" "workload" "owner" "costCenter")

# Export all resources with their tags
az resource list --query "[].{
  Name:name,
  Type:type,
  ResourceGroup:resourceGroup,
  Tags:tags
}" -o json > resources-with-tags.json

# Count resources missing 'env' tag
az resource list --query "[?tags.env==null].{Name:name, Type:type, RG:resourceGroup}" -o table

# Count resources missing 'workload' tag
az resource list --query "[?tags.workload==null].{Name:name, Type:type, RG:resourceGroup}" -o table

# Count resources missing 'owner' tag
az resource list --query "[?tags.owner==null].{Name:name, Type:type, RG:resourceGroup}" -o table

# Count resources missing 'costCenter' tag
az resource list --query "[?tags.costCenter==null].{Name:name, Type:type, RG:resourceGroup}" -o table

# Get tag compliance percentage
TOTAL=$(az resource list --query "length(@)")
MISSING_ENV=$(az resource list --query "[?tags.env==null] | length(@)")
echo "Tag Compliance (env): $((100 - ($MISSING_ENV * 100 / $TOTAL)))%"
```

### 5.3 Tag Audit Checklist

| # | Check | Command | Total | Missing | % Compliant | Score |
|---|-------|---------|-------|---------|-------------|-------|
| 5.3.1 | Resources with `env` tag | | | | | |
| 5.3.2 | Resources with `workload` tag | | | | | |
| 5.3.3 | Resources with `owner` tag | | | | | |
| 5.3.4 | Resources with `costCenter` tag | | | | | |
| 5.3.5 | App Services fully tagged | | | | | |
| 5.3.6 | App Insights fully tagged | | | | | |
| 5.3.7 | LAW fully tagged | | | | | |
| 5.3.8 | Consistent tag values (no typos) | | | | | |
| 5.3.9 | Environment values standardized | | | | | |
| 5.3.10 | Azure Policy for tags exists | | | | | |

### 5.4 Tag Policy Check

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

## 6. Application Insights Configuration

### 6.1 App Insights Inventory

```bash
# Full App Insights inventory
az monitor app-insights component list --query "[].{
  Name:name,
  ResourceGroup:resourceGroup,
  Location:location,
  IngestionMode:ingestionMode,
  WorkspaceId:workspaceResourceId,
  RetentionDays:retentionInDays,
  SamplingPercentage:samplingPercentage,
  DisableIpMasking:disableIpMasking,
  PublicIngestion:publicNetworkAccessForIngestion,
  PublicQuery:publicNetworkAccessForQuery
}" -o table
```

### 6.2 App Insights Audit Checklist

| # | Check | Expected | Command | Finding | Score |
|---|-------|----------|---------|---------|-------|
| 6.2.1 | Ingestion mode is LogAnalytics | `LogAnalytics` | See above | | |
| 6.2.2 | Linked to Log Analytics Workspace | Not null | | | |
| 6.2.3 | IP masking enabled (GDPR) | `true` (disableIpMasking=false) | | | |
| 6.2.4 | Retention configured | 30-90 days | | | |
| 6.2.5 | Sampling configured | Documented | | | |
| 6.2.6 | Connection string (not iKey) used | Check app settings | | | |
| 6.2.7 | Unique App Insights per component | 1:1 mapping | | | |
| 6.2.8 | Daily cap configured (cost control) | If budget limited | | | |

### 6.3 Connection String vs Instrumentation Key Check

```bash
# Check App Services for modern connection string usage
az webapp list --query "[].{
  Name:name,
  ResourceGroup:resourceGroup
}" -o tsv | while read name rg; do
  echo "=== $name ==="
  az webapp config appsettings list -n "$name" -g "$rg" \
    --query "[?name=='APPLICATIONINSIGHTS_CONNECTION_STRING' || name=='APPINSIGHTS_INSTRUMENTATIONKEY'].{Setting:name, HasValue:value!=null}" -o table
done

# CRITICAL: Apps using only APPINSIGHTS_INSTRUMENTATIONKEY should migrate to connection string
```

### 6.4 App Insights to App Service Mapping

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

## 7. Log Analytics Workspace Assessment

### 7.1 LAW Inventory

```bash
# Full LAW inventory
az monitor log-analytics workspace list --query "[].{
  Name:name,
  ResourceGroup:resourceGroup,
  Location:location,
  Sku:sku.name,
  RetentionDays:retentionInDays,
  DailyCapGb:workspaceCapping.dailyQuotaGb,
  IngestionStatus:workspaceCapping.quotaNextResetTime,
  PublicIngestion:publicNetworkAccessForIngestion,
  PublicQuery:publicNetworkAccessForQuery
}" -o table
```

### 7.2 LAW Audit Checklist

| # | Check | Expected | Finding | Score |
|---|-------|----------|---------|-------|
| 7.2.1 | SKU is PerGB2018 (pay-as-you-go) | `PerGB2018` | | |
| 7.2.2 | Retention appropriate for env | Dev: 30d, Prod: 90d+ | | |
| 7.2.3 | Daily cap configured (cost control) | If budget limited | | |
| 7.2.4 | One LAW per environment | Best practice | | |
| 7.2.5 | Cross-region LAW strategy documented | | | |
| 7.2.6 | Data export configured (if needed) | | | |
| 7.2.7 | Private link (if required) | | | |

### 7.3 LAW Data Volume Analysis

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

### 7.4 Per-Table Retention Check

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

## 8. Distributed Tracing & Correlation

### 8.1 Tracing Configuration Checklist

| # | Check | Expected | How to Verify | Finding | Score |
|---|-------|----------|---------------|---------|-------|
| 8.1.1 | W3C TraceContext enabled | Default in modern SDKs | Check SDK version | | |
| 8.1.2 | `cloud_RoleName` set per service | Unique per component | KQL query | | |
| 8.1.3 | `cloud_RoleInstance` populated | Auto or configured | KQL query | | |
| 8.1.4 | Operation correlation working | Traces span services | KQL query | | |
| 8.1.5 | HTTP header propagation enabled | `traceparent` header | Test request | | |
| 8.1.6 | SDK version is current | Check for updates | | | |

### 8.2 Verify cloud_RoleName Configuration

```kql
// Run in Log Analytics or App Insights Logs
// Check if cloud_RoleName is properly set

requests
| where timestamp > ago(24h)
| summarize RequestCount = count() by cloud_RoleName
| order by RequestCount desc

// ISSUE: If cloud_RoleName is empty or generic, services cannot be distinguished
```

### 8.3 Verify Trace Correlation

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

### 8.4 Check Dependency Tracking

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

### 8.5 SDK Version Audit

```bash
# Check OpenTelemetry / App Insights SDK versions in App Services
az webapp list --query "[].{Name:name, ResourceGroup:resourceGroup}" -o tsv | while read name rg; do
  echo "=== $name ==="
  az webapp config appsettings list -n "$name" -g "$rg" \
    --query "[?contains(name, 'OTEL') || contains(name, 'APPINSIGHTS') || contains(name, 'APPLICATIONINSIGHTS')].{Setting:name, Value:value}" -o table
done
```

---

## 9. Sampling Configuration

### 9.1 Sampling Strategy Assessment

| # | Check | Expected | Finding | Score |
|---|-------|----------|---------|-------|
| 9.1.1 | Sampling strategy documented | Yes | | |
| 9.1.2 | Dev environment sampling | 100% (no sampling) | | |
| 9.1.3 | Prod environment sampling | 10-25% typical | | |
| 9.1.4 | Sampling type (fixed vs adaptive) | Document | | |
| 9.1.5 | Critical transactions excluded from sampling | If applicable | | |

### 9.2 Check Sampling Configuration

```bash
# Check OTEL sampling configuration
az webapp config appsettings list -n <app-name> -g <rg> \
  --query "[?contains(name, 'SAMPLING') || contains(name, 'SAMPLER')].{Setting:name, Value:value}" -o table

# Check App Insights sampling
az monitor app-insights component show --app <appi-name> -g <rg> \
  --query "{SamplingPercentage:samplingPercentage}"
```

### 9.3 Verify Sampling Impact

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

### 9.4 Sampling Audit Checklist

| Environment | Expected Rate | Actual Rate | itemCount Check | Score |
|-------------|---------------|-------------|-----------------|-------|
| Development | 100% | | | |
| Staging | 50-100% | | | |
| Production | 10-25% | | | |

---

## 10. Retention & Cost Optimization

### 10.1 Retention Configuration Audit

| # | Check | Dev Expected | Prod Expected | Finding | Score |
|---|-------|--------------|---------------|---------|-------|
| 10.1.1 | LAW default retention | 30 days | 90 days | | |
| 10.1.2 | App Insights retention | 30 days | 90 days | | |
| 10.1.3 | Per-table retention configured | Optional | Yes | | |
| 10.1.4 | Archive tier used | No | Optional | | |
| 10.1.5 | Data export for long-term | No | If compliance needed | | |

### 10.2 Cost Analysis Queries

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

### 10.3 High-Volume Table Identification

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

### 10.4 Cost Optimization Checklist

| # | Optimization | Status | Potential Savings | Priority |
|---|--------------|--------|-------------------|----------|
| 10.4.1 | Reduce verbose logging | | | |
| 10.4.2 | Implement sampling (prod) | | | |
| 10.4.3 | Reduce retention where possible | | | |
| 10.4.4 | Archive cold data | | | |
| 10.4.5 | Remove unused App Insights | | | |
| 10.4.6 | Consolidate LAWs | | | |
| 10.4.7 | Filter unnecessary telemetry | | | |
| 10.4.8 | Use Basic logs tier for verbose data | | | |

### 10.5 Budget Alert Check

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

## 11. Alerting & Action Groups

### 11.1 Action Group Inventory

```bash
# List all action groups
az monitor action-group list --query "[].{
  Name:name,
  ResourceGroup:resourceGroup,
  EmailCount:length(emailReceivers),
  SmsCount:length(smsReceivers),
  WebhookCount:length(webhookReceivers),
  LogicAppCount:length(logicAppReceivers),
  Enabled:enabled
}" -o table
```

### 11.2 Alert Rules Inventory

```bash
# Metric alerts
az monitor metrics alert list --query "[].{
  Name:name,
  ResourceGroup:resourceGroup,
  Severity:severity,
  Enabled:enabled,
  TargetResource:scopes[0]
}" -o table

# Log/scheduled query alerts
az monitor scheduled-query list --query "[].{
  Name:name,
  ResourceGroup:resourceGroup,
  Severity:severity,
  Enabled:enabled
}" -o table 2>/dev/null
```

### 11.3 Alert Coverage Audit

| # | Check | Expected | Finding | Score |
|---|-------|----------|---------|-------|
| 11.3.1 | Action Group exists | At least 1 per env | | |
| 11.3.2 | Email receivers configured | Yes | | |
| 11.3.3 | HTTP 5xx alert exists | Yes, per app | | |
| 11.3.4 | Response time alert exists | Yes, per app | | |
| 11.3.5 | Exception alert exists | Yes, per app | | |
| 11.3.6 | Availability alert exists | For prod apps | | |
| 11.3.7 | CPU/Memory alerts (App Service Plan) | Optional | | |
| 11.3.8 | Dependency failure alerts | For prod | | |
| 11.3.9 | Auto-mitigate enabled | Yes | | |
| 11.3.10 | Alert severity appropriate | Prod=0-1, Dev=2-3 | | |

### 11.4 Alert Best Practices Check

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

### 11.5 Missing Alerts Detection

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

## 12. Diagnostic Settings

### 12.1 Diagnostic Settings Inventory

```bash
# Check diagnostic settings for App Services
az webapp list --query "[].{Name:name, ResourceGroup:resourceGroup, Id:id}" -o tsv | while read name rg id; do
  echo "=== $name ==="
  az monitor diagnostic-settings list --resource "$id" \
    --query "[].{Name:name, WorkspaceId:workspaceId, Categories:logs[*].category}" -o table 2>/dev/null || echo "No diagnostic settings"
done
```

### 12.2 Diagnostic Settings Checklist

| # | Check | Expected | Finding | Score |
|---|-------|----------|---------|-------|
| 12.2.1 | App Service diagnostic settings exist | Yes | | |
| 12.2.2 | Logs sent to LAW | Yes | | |
| 12.2.3 | AppServiceHTTPLogs enabled | Yes | | |
| 12.2.4 | AppServiceConsoleLogs enabled | Optional | | |
| 12.2.5 | AppServiceAppLogs enabled | Yes | | |
| 12.2.6 | AppServicePlatformLogs enabled | Yes | | |
| 12.2.7 | Metrics sent to LAW | Optional | | |
| 12.2.8 | Retention configured | Match LAW | | |

### 12.3 Recommended Diagnostic Categories

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

## 13. RBAC & Security

### 13.1 Monitoring RBAC Roles

```bash
# Check monitoring-specific role assignments
az role assignment list --all --query "[?contains(roleDefinitionName, 'Monitoring') || contains(roleDefinitionName, 'Log Analytics')].{
  Principal:principalName,
  Role:roleDefinitionName,
  Scope:scope
}" -o table
```

### 13.2 RBAC Audit Checklist

| # | Check | Expected | Finding | Score |
|---|-------|----------|---------|-------|
| 13.2.1 | Monitoring Reader role assigned | For read-only users | | |
| 13.2.2 | Monitoring Contributor role assigned | For ops team | | |
| 13.2.3 | Log Analytics Reader assigned | For query access | | |
| 13.2.4 | Log Analytics Contributor assigned | For LAW admins | | |
| 13.2.5 | No Owner/Contributor for monitoring only | Least privilege | | |
| 13.2.6 | Service principals have minimal scope | | | |
| 13.2.7 | PIM used for privileged roles | If available | | |

### 13.3 Data Privacy Check

| # | Check | Expected | Finding | Score |
|---|-------|----------|---------|-------|
| 13.3.1 | IP masking enabled in App Insights | Yes (GDPR) | | |
| 13.3.2 | PII not logged (spot check) | No PII in logs | | |
| 13.3.3 | Data residency (LAW location) | Same as data region | | |
| 13.3.4 | Customer-managed keys (if required) | Document | | |
| 13.3.5 | Private endpoints (if required) | Document | | |

### 13.4 Check IP Masking

```bash
# Verify IP masking is enabled (disableIpMasking should be false/null)
az monitor app-insights component list --query "[].{
  Name:name,
  DisableIpMasking:disableIpMasking
}" -o table

# WARNING: If disableIpMasking is true, real IPs are stored (GDPR concern)
```

---

## 14. Governance & Policies

### 14.1 Azure Policy Inventory

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

### 14.2 Governance Checklist

| # | Check | Expected | Finding | Score |
|---|-------|----------|---------|-------|
| 14.2.1 | Tag enforcement policy exists | Yes | | |
| 14.2.2 | Diagnostic settings policy exists | Yes | | |
| 14.2.3 | Allowed locations policy exists | If data residency required | | |
| 14.2.4 | Policies in Audit mode (not blocking) | Document | | |
| 14.2.5 | Policy compliance monitored | Yes | | |
| 14.2.6 | Exception process documented | Yes | | |

### 14.3 Policy Compliance Summary

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

## 15. Workbooks & Dashboards

### 15.1 Workbook Inventory

```bash
# List Azure Monitor Workbooks
az monitor app-insights workbook list --query "[].{
  Name:name,
  DisplayName:displayName,
  Category:category,
  ResourceGroup:resourceGroup
}" -o table 2>/dev/null
```

### 15.2 Dashboard Inventory

```bash
# List Azure Dashboards
az portal dashboard list --query "[].{
  Name:name,
  ResourceGroup:resourceGroup,
  Location:location
}" -o table 2>/dev/null
```

### 15.3 Visualization Checklist

| # | Check | Expected | Finding | Score |
|---|-------|----------|---------|-------|
| 15.3.1 | Operations workbook exists | Yes | | |
| 15.3.2 | Workbook covers all environments | Yes | | |
| 15.3.3 | Dashboard for executive view | Optional | | |
| 15.3.4 | Workbook sections: Overview | Yes | | |
| 15.3.5 | Workbook sections: Failures | Yes | | |
| 15.3.6 | Workbook sections: Performance | Yes | | |
| 15.3.7 | Workbook sections: Dependencies | Yes | | |
| 15.3.8 | Workbook sections: Alerts | Yes | | |
| 15.3.9 | Time range picker available | Yes | | |
| 15.3.10 | Environment filter available | Yes | | |

---

## 16. Scoring Matrix

### 16.1 Category Weights

| Category | Weight | Max Score |
|----------|--------|-----------|
| 3. Monitoring Strategy | 15% | 15 |
| 4. Naming Conventions | 10% | 10 |
| 5. Tagging Compliance | 10% | 10 |
| 6. Application Insights | 15% | 15 |
| 7. Log Analytics | 10% | 10 |
| 8. Distributed Tracing | 15% | 15 |
| 9. Sampling | 5% | 5 |
| 10. Retention & Costs | 10% | 10 |
| 11. Alerting | 10% | 10 |
| **Total** | **100%** | **100** |

### 16.2 Scoring Guide

| Score | Rating | Description |
|-------|--------|-------------|
| 0 | ❌ Critical | Not implemented, critical gap |
| 1 | ⚠️ Major | Partially implemented, major issues |
| 2 | 🟡 Minor | Mostly implemented, minor issues |
| 3 | ✅ Good | Fully implemented, meets best practices |

### 16.3 Overall Score Card

| Category | Score | Max | % | Rating |
|----------|-------|-----|---|--------|
| Monitoring Strategy | | 15 | | |
| Naming Conventions | | 10 | | |
| Tagging Compliance | | 10 | | |
| Application Insights | | 15 | | |
| Log Analytics | | 10 | | |
| Distributed Tracing | | 15 | | |
| Sampling | | 5 | | |
| Retention & Costs | | 10 | | |
| Alerting | | 10 | | |
| **TOTAL** | | **100** | | |

### 16.4 Maturity Level

| Score Range | Maturity Level | Description |
|-------------|----------------|-------------|
| 0-25 | Level 1: Initial | Ad-hoc monitoring, no standards |
| 26-50 | Level 2: Developing | Basic monitoring, inconsistent |
| 51-75 | Level 3: Defined | Standards exist, partially followed |
| 76-90 | Level 4: Managed | Consistent implementation, measured |
| 91-100 | Level 5: Optimized | Best practices, continuous improvement |

---

## 17. Remediation Priorities

### 17.1 Priority Matrix

| Priority | Criteria | Timeline |
|----------|----------|----------|
| P1 - Critical | Security gaps, data loss risk, compliance violations | Immediate (1 week) |
| P2 - High | Missing core monitoring, alert gaps | Short-term (2-4 weeks) |
| P3 - Medium | Non-compliance with standards, cost inefficiencies | Medium-term (1-2 months) |
| P4 - Low | Nice-to-have improvements, optimizations | Backlog |

### 17.2 Common Findings & Remediation

| Finding | Priority | Remediation | Effort |
|---------|----------|-------------|--------|
| Classic App Insights in use | P1 | Migrate to workspace-based | Medium |
| No alerts configured | P1 | Deploy baseline alert set | Low |
| PII in logs | P1 | Implement safe logging, purge data | High |
| Missing tags | P2 | Deploy tag policy, remediate | Low |
| No diagnostic settings | P2 | Deploy diagnostic settings | Low |
| Instrumentation key (not connection string) | P2 | Update to connection string | Low |
| High data ingestion costs | P3 | Implement sampling, filter logs | Medium |
| No workbooks/dashboards | P3 | Deploy standard workbook | Low |
| Inconsistent naming | P4 | Document standards, rename new resources | Low |
| No distributed tracing | P2 | Configure cloud_RoleName, verify correlation | Medium |

### 17.3 Remediation Tracking Template

| ID | Finding | Category | Priority | Owner | Due Date | Status |
|----|---------|----------|----------|-------|----------|--------|
| R001 | | | | | | |
| R002 | | | | | | |
| R003 | | | | | | |

---

## Appendix A: Quick Reference Commands

### A.1 One-Liner Audit Commands

```bash
# Count resources missing App Insights
az webapp list --query "[].name" -o tsv | wc -l && \
az webapp list --query "[?siteConfig.appSettings[?name=='APPLICATIONINSIGHTS_CONNECTION_STRING']].name" -o tsv | wc -l

# List classic App Insights (need migration)
az monitor app-insights component list --query "[?ingestionMode!='LogAnalytics'].name" -o tsv

# List resources without required tags
az resource list --query "[?tags.env==null || tags.workload==null || tags.owner==null].{Name:name, Type:type}" -o table

# Count enabled vs disabled alerts
az monitor scheduled-query list --query "{Enabled:length([?enabled==true]), Disabled:length([?enabled==false])}" 2>/dev/null

# LAW retention summary
az monitor log-analytics workspace list --query "[].{Name:name, Retention:retentionInDays}" -o table
```

### A.2 Export All Audit Data

```bash
#!/bin/bash
# Export comprehensive audit data

AUDIT_DIR="audit-$(date +%Y%m%d)"
mkdir -p $AUDIT_DIR

az resource list -o json > $AUDIT_DIR/all-resources.json
az webapp list -o json > $AUDIT_DIR/app-services.json
az functionapp list -o json > $AUDIT_DIR/function-apps.json
az monitor app-insights component list -o json > $AUDIT_DIR/app-insights.json
az monitor log-analytics workspace list -o json > $AUDIT_DIR/log-analytics.json
az monitor action-group list -o json > $AUDIT_DIR/action-groups.json
az monitor scheduled-query list -o json 2>/dev/null > $AUDIT_DIR/scheduled-queries.json
az monitor metrics alert list -o json > $AUDIT_DIR/metric-alerts.json
az policy assignment list -o json > $AUDIT_DIR/policy-assignments.json

echo "Audit data exported to $AUDIT_DIR/"
```

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

*Checklist Version: 1.0 | Last Updated: February 3, 2026*
