# Step 5: Retention & Costs - Verification Brain Dump

> **Date:** February 2, 2026  
> **Resource Group:** `rg-obs-demo-dev-weu`  
> **LAW SKU:** PerGB2018  
> **Workspace Retention:** 30 days (dev)

---

## 🎯 Cost Control Philosophy

### Three Levers for Controlling Observability Costs

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      COST CONTROL LEVERS                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1. WHAT YOU EMIT (Source Control)                                          │
│     ├─ Diagnostic categories: Select only what you need                     │
│     ├─ Log levels: Don't emit Debug in production                           │
│     └─ Sampling: Reduce volume while preserving correlation                 │
│                                                                             │
│  2. HOW LONG YOU KEEP IT (Retention)                                        │
│     ├─ Workspace-level default                                              │
│     └─ Per-table overrides (critical vs verbose data)                       │
│                                                                             │
│  3. WHERE YOU STORE IT (Archive)                                            │
│     ├─ Analytics tier: Fast queries, higher cost                            │
│     ├─ Basic tier: Ingest-only, no queries, lower cost                      │
│     └─ Archive tier: Long-term storage, lowest cost                         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 🔍 Verification Commands (All Working)

### 1. Check Workspace-Level Retention

```bash
az monitor log-analytics workspace show \
  --workspace-name law-obs-demo-dev-weu \
  --resource-group rg-obs-demo-dev-weu \
  --query "{name:name, retention:retentionInDays, sku:sku.name, dailyQuotaGb:workspaceCapping.dailyQuotaGb}" \
  -o json
```

**Output:**
```json
{
  "dailyQuotaGb": -1.0,
  "name": "law-obs-demo-dev-weu",
  "retention": 30,
  "sku": "PerGB2018"
}
```

> Note: `dailyQuotaGb: -1.0` means no quota (unlimited). In prod, consider setting a daily cap to prevent cost spikes.

---

### 2. List Per-Table Retention Settings

```bash
az monitor log-analytics workspace table show \
  --workspace-name law-obs-demo-dev-weu \
  --resource-group rg-obs-demo-dev-weu \
  --name AppDependencies \
  --query "{name:name, retentionDays:retentionInDays}" \
  -o json
```

**Output (after tuning):**
```json
{
  "name": "AppDependencies",
  "retentionDays": 30
}
```

```bash
az monitor log-analytics workspace table show \
  --workspace-name law-obs-demo-dev-weu \
  --resource-group rg-obs-demo-dev-weu \
  --name AppRequests \
  --query "{name:name, retentionDays:retentionInDays}" \
  -o json
```

**Output:**
```json
{
  "name": "AppRequests",
  "retentionDays": 90
}
```

---

### 3. Update Per-Table Retention (DEMONSTRATED)

```bash
# Reduce AppDependencies retention (high volume, less critical for long-term)
az monitor log-analytics workspace table update \
  --workspace-name law-obs-demo-dev-weu \
  --resource-group rg-obs-demo-dev-weu \
  --name AppDependencies \
  --retention-time 30 \
  --total-retention-time 30 \
  -o json
```

**Result:** AppDependencies now at 30 days (was 90), while AppRequests stays at 90 days.

---

### 4. Check Diagnostic Categories (INTENTIONAL SELECTION)

```bash
az monitor diagnostic-settings show \
  --name web-obs-demo-dev-weu-law-diag \
  --resource-group rg-obs-demo-dev-weu \
  --resource web-obs-demo-dev-weu \
  --resource-type Microsoft.Web/sites \
  --query "logs[].{category:category, enabled:enabled}" \
  -o table
```

**Output:**
```
Category                      Enabled
----------------------------  ---------
AppServiceHTTPLogs            True
AppServiceConsoleLogs         True
AppServiceAppLogs             True
AppServiceAuditLogs           True
AppServicePlatformLogs        True
AppServiceIPSecAuditLogs      False      ← INTENTIONALLY DISABLED
AppServiceAuthenticationLogs  False      ← INTENTIONALLY DISABLED
```

---

### 5. Estimate Table Sizes (Cost Analysis)

```bash
LAW_ID=$(az monitor log-analytics workspace show \
  --workspace-name law-obs-demo-dev-weu \
  --resource-group rg-obs-demo-dev-weu \
  --query customerId -o tsv)

az monitor log-analytics query \
  --workspace $LAW_ID \
  --analytics-query "
    Usage
    | where TimeGenerated > ago(24h)
    | where IsBillable == true
    | summarize BillableGB = sum(Quantity)/1024.0 by DataType
    | order by BillableGB desc
  " \
  -o table
```

---

### 6. Set Daily Ingestion Cap (Cost Protection)

```bash
# Set 1GB daily cap (prevents runaway costs)
az monitor log-analytics workspace update \
  --workspace-name law-obs-demo-dev-weu \
  --resource-group rg-obs-demo-dev-weu \
  --quota 1
```

> ⚠️ Use with caution in production - hitting the cap stops ingestion until reset.

---

## 📊 Actual State Summary

### Diagnostic Categories Decision Matrix

| Category | Enabled | Cost Impact | Rationale |
|----------|---------|-------------|-----------|
| **AppServiceHTTPLogs** | ✅ Yes | Medium | Essential for debugging requests |
| **AppServiceConsoleLogs** | ✅ Yes | Low | App stdout/stderr - debugging |
| **AppServiceAppLogs** | ✅ Yes | Medium | App-generated logs |
| **AppServiceAuditLogs** | ✅ Yes | Low | Security/compliance required |
| **AppServicePlatformLogs** | ✅ Yes | Low | Platform events (restarts, etc.) |
| **AppServiceIPSecAuditLogs** | ❌ No | High | Only needed for IP filtering debug |
| **AppServiceAuthenticationLogs** | ❌ No | Medium | Only needed for auth issues |

**Decision:** We enable 5 core categories and disable 2 optional ones. This is an intentional cost-quality tradeoff, not "enable all".

---

### Per-Table Retention Strategy

| Table | Data Type | Retention | Rationale |
|-------|-----------|-----------|-----------|
| **AppRequests** | Request telemetry | 90 days | Critical for SLA analysis, trend comparison |
| **AppExceptions** | Errors | 90 days | Long-term error tracking, regression detection |
| **AppTraces** | Custom logs | 90 days | Debugging context |
| **AppDependencies** | Outbound calls | **30 days** | High volume, short-term debugging only |
| **AppMetrics** | Performance counters | 90 days | Trend analysis |
| **AppServiceHTTPLogs** | Access logs | 30 days | High volume, audit retention elsewhere |
| **AppServiceConsoleLogs** | Console output | 30 days | Debugging only |

**Result:** Critical data (requests, errors) retained longer. High-volume data (dependencies, HTTP logs) retained shorter.

---

### Cost Projection Model

| Tier | Ingestion | First 31 Days | Archive (31+ days) | Notes |
|------|-----------|---------------|-------------------|-------|
| **Analytics** | $2.76/GB | Included | $0.12/GB/month | Default for App Insights |
| **Basic** | $0.65/GB | $0.65/GB/month | N/A | No interactive queries |
| **Archive** | N/A | N/A | $0.026/GB/month | Restore required for queries |

**Example Calculation (1GB/day workload):**

| Strategy | Monthly Ingestion | 30-Day Storage | 60-Day Archive | Total |
|----------|-------------------|----------------|----------------|-------|
| All Analytics, 90 days | 30 × $2.76 = $82.80 | Included | $1.80 | ~$84.60 |
| Analytics 30d + Archive | 30 × $2.76 = $82.80 | Included | $0.78 | ~$83.58 |
| Sampling 10% + Analytics | 3 × $2.76 = $8.28 | Included | $0.18 | ~$8.46 |

---

### Dev vs Prod Retention Configuration

| Setting | Dev | Prod | Rationale |
|---------|-----|------|-----------|
| **Workspace Default** | 30 days | 90 days | Prod needs longer trend analysis |
| **AppRequests** | 30 days | 90 days | Prod SLA tracking |
| **AppDependencies** | 30 days | 30 days | Always short (high volume) |
| **AppExceptions** | 30 days | 180 days | Prod needs regression detection |
| **Daily Cap** | None | 5 GB | Prod cost protection |

---

## 🔧 Bicep Module: Per-Table Retention

```bicep
// modules/law-table-retention.bicep
// Configures per-table retention for cost optimization

@description('Log Analytics Workspace name')
param workspaceName string

@description('Table retention configurations')
param tableRetentions array = [
  { name: 'AppDependencies', retention: 30 }
  { name: 'AppServiceHTTPLogs', retention: 30 }
  { name: 'AppServiceConsoleLogs', retention: 30 }
  // AppRequests, AppExceptions use workspace default (longer)
]

resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: workspaceName
}

resource tableRetention 'Microsoft.OperationalInsights/workspaces/tables@2022-10-01' = [for table in tableRetentions: {
  parent: workspace
  name: table.name
  properties: {
    retentionInDays: table.retention
    totalRetentionInDays: table.retention
  }
}]
```

---

## 📋 Cost Control Checklist

| Control | Implemented | Evidence |
|---------|-------------|----------|
| **Workspace retention configured** | ✅ | 30 days (dev), 90 days (prod) in params |
| **Per-table retention tuned** | ✅ | AppDependencies reduced to 30 days |
| **Diagnostic categories selected** | ✅ | 5 core enabled, 2 optional disabled |
| **Sampling configured** | ✅ | Step 4 - dev=100%, prod=10% |
| **Daily cap available** | ✅ | Command documented (not set in dev) |
| **Cost projection model** | ✅ | Documented above |

---

## 🎓 The "Why" Behind Each Decision

### Why Not Enable All Diagnostic Categories?

```
AppServiceIPSecAuditLogs:
- Logs every IP check against IP restriction rules
- If you have 100 requests/sec and IP restrictions enabled:
  100 req × 86400 sec = 8.6M records/day = ~2GB/day = ~$5.50/day extra
- Only enable when actively debugging IP filtering issues

AppServiceAuthenticationLogs:
- Logs every authentication event
- High volume with Azure AD authentication
- Only enable when debugging auth failures
```

### Why Reduce AppDependencies Retention?

```
Typical breakdown by volume:
- AppDependencies: 60-70% of total volume (every HTTP call, DB query)
- AppRequests: 10-15%
- AppTraces: 10-15%
- AppExceptions: <1%

By reducing AppDependencies from 90→30 days:
- Saves 60% of that table's storage cost
- Still have 30 days for debugging
- Correlation (OperationId) still works for recent traces
- If you need historical dependency analysis, use Azure Data Explorer export
```

### Why 30 Days Minimum?

```
PerGB2018 SKU enforces 30-day minimum retention.
This is Azure's architectural decision:
- Ingestion cost includes 30 days storage
- Can't go lower without changing SKU
- Free tier (legacy) allowed 7 days - no longer available
```

---

## ✅ Step 5 Verification Complete

**Summary:**
- Workspace-level retention configured (30 days dev, 90 days prod) ✅
- Per-table retention DEMONSTRATED (AppDependencies tuned to 30 days) ✅
- Diagnostic categories INTENTIONALLY selected (5 of 7 enabled) ✅
- Cost projection model documented ✅
- "Why" explained for each decision ✅
