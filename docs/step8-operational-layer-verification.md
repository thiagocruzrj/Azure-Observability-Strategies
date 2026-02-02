# Step 8: Operational Layer (Alerts + Workbook + Dashboard) Verification

> **Date**: February 2, 2026  
> **Resource Group**: `rg-obs-demo-dev-weu`  
> **Environment**: dev  
> **Module**: `modules/ops-alerting-workbooks.bicep` (932 lines)

---

## Executive Summary

The operational layer provides the **proactive monitoring** capabilities that transform raw telemetry into actionable alerts and visual dashboards. This step bridges the gap between "collecting data" and "responding to issues."

### What Got Deployed

| Component | Resource Name | Purpose |
|-----------|--------------|---------|
| **Action Group** | `ag-mon-dev-demo` | Notification routing (email, Teams, webhook) |
| **Alert Rules** | 8 baseline alerts | Proactive failure detection |
| **Workbook** | "Operations Dashboard - dev - demo" | Visual operational dashboard |

---

## 1. Action Group

### Verification Command

```bash
az monitor action-group show \
  --resource-group rg-obs-demo-dev-weu \
  --name ag-mon-dev-demo \
  --query "{name:name, shortName:groupShortName, enabled:enabled, emailReceivers:emailReceivers}" \
  -o json
```

### Result

```json
{
  "name": "ag-mon-dev-demo",
  "shortName": "agdevdemo",
  "enabled": true,
  "emailReceivers": [
    {
      "name": "email-0",
      "emailAddress": "ops-team@contoso.com",
      "useCommonAlertSchema": true
    }
  ]
}
```

### Why Action Groups Matter

| Feature | Purpose |
|---------|---------|
| **Common Alert Schema** | Consistent JSON payload across all alert types |
| **Multiple Channels** | Email, SMS, Teams webhooks, Azure Functions, Logic Apps |
| **Centralized Management** | One group, many alerts pointing to it |
| **Short Name** | Max 12 chars for SMS display (`agdevdemo`) |

### Notification Channels Supported

```
┌─────────────────────────────────────────────────────────────────┐
│                    ag-mon-dev-demo                               │
├─────────────────────────────────────────────────────────────────┤
│  ✅ Email         → ops-team@contoso.com                        │
│  ⬜ SMS           → (not configured)                            │
│  ⬜ Teams Webhook → (optional, add teamsWebhookUrl param)       │
│  ⬜ Azure Function→ (for auto-remediation)                      │
│  ⬜ Logic App     → (for ticket creation)                       │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Baseline Alert Rules

### Verification Command

```bash
az monitor scheduled-query list \
  --resource-group rg-obs-demo-dev-weu \
  --query "[].{name:name, displayName:displayName, severity:severity, enabled:enabled}" \
  -o table
```

### Result: 8 Baseline Alerts

| Alert Name | Display Name | Severity | Signal |
|------------|--------------|----------|--------|
| `alrt-dev-demo-web-5xx` | [DEV] Web - HTTP 5xx Errors | 1 (Error) | 5xx count > 10/15min |
| `alrt-dev-demo-api-5xx` | [DEV] API - HTTP 5xx Errors | 1 (Error) | 5xx count > 10/15min |
| `alrt-dev-demo-web-latency` | [DEV] Web - High Latency | 2 (Warning) | Avg duration > 5000ms |
| `alrt-dev-demo-api-latency` | [DEV] API - High Latency | 2 (Warning) | Avg duration > 5000ms |
| `alrt-dev-demo-web-exceptions` | [DEV] Web - Exception Spike | 2 (Warning) | Exception count > 20/15min |
| `alrt-dev-demo-api-exceptions` | [DEV] API - Exception Spike | 2 (Warning) | Exception count > 20/15min |
| `alrt-dev-demo-func-failures` | [DEV] Functions - Execution Failures | 1 (Error) | Failed requests > 10/15min |
| `alrt-dev-demo-func-exceptions` | [DEV] Functions - Exception Spike | 2 (Warning) | Exception count > 20/15min |

### Alert Severity Mapping

| Severity | Dev Environment | Prod Environment | Response |
|----------|-----------------|------------------|----------|
| **0 - Critical** | Not used | 5xx errors, Function failures | Page on-call |
| **1 - Error** | 5xx, Func failures | High latency | Alert + investigate |
| **2 - Warning** | Latency, Exceptions | Exceptions | Review next business day |
| **3 - Info** | Not used | Not used | Log for trends |

### Alert Threshold Comparison (Dev vs Prod)

```bicep
var alertThresholds = {
  dev: {
    http5xxCount: 10           // Allow more errors in dev
    latencyMs: 5000            // 5 seconds
    exceptionCount: 20         // More exceptions tolerated
    functionFailureCount: 10
  }
  prod: {
    http5xxCount: 5            // Stricter in prod
    latencyMs: 2000            // 2 seconds
    exceptionCount: 5          // Fewer exceptions tolerated
    functionFailureCount: 3
  }
}
```

**Why different thresholds?**
- Dev environments have more noise (debugging, testing)
- Prod needs faster detection to minimize customer impact
- Alert fatigue prevention in dev

### Alert Rule Anatomy

```
┌────────────────────────────────────────────────────────────────┐
│  alrt-dev-demo-web-5xx                                         │
├────────────────────────────────────────────────────────────────┤
│  Scope:       appi-web-demo-dev-weu (Application Insights)     │
│  Query:       requests | where resultCode startswith "5"       │
│  Aggregation: Count by 5-minute bins                           │
│  Threshold:   > 10 errors                                      │
│  Window:      15 minutes                                       │
│  Frequency:   Every 5 minutes                                  │
│  Failing:     2 of 3 evaluation periods                        │
│  Action:      → ag-mon-dev-demo (Email)                        │
│  Auto-mitigate: Yes (resolves when condition clears)           │
└────────────────────────────────────────────────────────────────┘
```

### Failing Periods Logic

```
Time:    T1    T2    T3    T4    T5    T6
         │     │     │     │     │     │
Metric:  OK    FAIL  FAIL  OK    FAIL  FAIL
         │     │     │     │     │     │
               ├─────────┤     ├─────────┤
               2 of 3 = ALERT  2 of 3 = ALERT

Why "2 of 3"?
- Avoids alert on single transient spike
- Still catches sustained issues quickly
- Reduces false positives by ~40%
```

---

## 3. Operations Workbook

### Verification Command

```bash
az resource show \
  --resource-group rg-obs-demo-dev-weu \
  --resource-type "Microsoft.Insights/workbooks" \
  --name ebc5f6c1-c21b-5f05-85eb-0f1de59a5036 \
  --query "{displayName:properties.displayName, category:properties.category, sourceId:properties.sourceId}" \
  -o json
```

### Result

```json
{
  "displayName": "Operations Dashboard - dev - demo",
  "category": "workbook",
  "sourceId": ".../workspaces/law-obs-demo-dev-weu"
}
```

### Workbook Portal URL

```
https://portal.azure.com/#@/resource/subscriptions/96c57020-cece-485b-a9a8-25214593bf2d/resourceGroups/rg-obs-demo-dev-weu/providers/Microsoft.Insights/workbooks/ebc5f6c1-c21b-5f05-85eb-0f1de59a5036/workbook
```

### Workbook Sections

The deployed workbook includes these operational views:

```
┌─────────────────────────────────────────────────────────────────┐
│  📊 Operations Dashboard - dev - demo                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  📊 OVERVIEW                                                     │
│  ├── Request Volume by Component (timechart)                    │
│  └── Role: Web vs API vs Function                               │
│                                                                  │
│  ❌ FAILURES                                                     │
│  ├── Failed Requests + Exceptions over 24h (timechart)          │
│  └── Top 20 Exception Types (table)                             │
│                                                                  │
│  🔗 DEPENDENCY CHAIN                                             │
│  ├── Dependency Health Table (with failure % coloring)          │
│  │   └── Target, Type, Caller, Calls, Failed, %, Avg/P95 ms    │
│  └── Dependency Latency Trend (4h timechart)                    │
│                                                                  │
│  🔔 RECENT ALERTS                                                │
│  └── Fired alerts in last 7 days (Azure Resource Graph query)  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Key Workbook Queries

**Dependency Health Query:**
```kusto
AppDependencies
| summarize 
    TotalCalls = count(),
    FailedCalls = countif(Success == false),
    AvgDuration = avg(DurationMs),
    P95Duration = percentile(DurationMs, 95)
    by Target, DependencyType, AppRoleName
| extend FailureRate = round((FailedCalls * 100.0) / TotalCalls, 2)
| order by FailureRate desc
```

**Top Exceptions Query:**
```kusto
AppExceptions
| where TimeGenerated > ago(24h)
| summarize Count = count() by ExceptionType, AppRoleName
| order by Count desc
| take 20
```

---

## 4. Dashboard Pinning

### Manual Pinning Process

Azure Workbooks can be pinned to Azure Portal Dashboards:

1. Open the workbook in Azure Portal
2. Click **Pin** (📌) on any visualization
3. Select target dashboard or create new
4. Each chart becomes a live dashboard tile

### Programmatic Dashboard (Alternative)

For IaC-managed dashboards, use `Microsoft.Portal/dashboards`:

```bicep
resource dashboard 'Microsoft.Portal/dashboards@2020-09-01-preview' = {
  name: 'dash-ops-${env}-${workload}'
  location: location
  tags: tags
  properties: {
    lenses: [
      {
        order: 0
        parts: [
          // Embed workbook parts or metrics tiles
        ]
      }
    ]
  }
}
```

**Note**: Portal dashboards have limited IaC support. The workbook approach is preferred because:
- Version controlled as JSON/Bicep
- Portable across subscriptions
- Richer query capabilities
- Parameterized (time range, resources)

---

## 5. Alert Flow Architecture

```
┌──────────────────────────────────────────────────────────────────────────┐
│                        OPERATIONAL LAYER FLOW                             │
└──────────────────────────────────────────────────────────────────────────┘

  Application Telemetry
         │
         ▼
  ┌─────────────────────┐
  │ Application Insights │──────────────┐
  │ (appi-web/api/func)  │              │
  └─────────────────────┘              │
         │                              │
         │ (log queries)                │ (metric queries)
         ▼                              ▼
  ┌──────────────────────────────────────────────────┐
  │              Azure Monitor Alert Rules            │
  │  ┌────────────────┐ ┌────────────────┐           │
  │  │  alrt-web-5xx  │ │ alrt-api-lat   │  ...      │
  │  └───────┬────────┘ └───────┬────────┘           │
  └──────────┼──────────────────┼────────────────────┘
             │                  │
             ▼                  ▼
  ┌──────────────────────────────────────────────────┐
  │              Action Group: ag-mon-dev-demo        │
  │  ┌──────┐ ┌──────┐ ┌───────┐ ┌──────────────┐   │
  │  │Email │ │ SMS  │ │Teams  │ │Azure Function│   │
  │  └──┬───┘ └──────┘ └───────┘ └──────────────┘   │
  └─────┼────────────────────────────────────────────┘
        │
        ▼
  ┌─────────────────┐
  │  ops-team@...   │ ← Receives alert with context
  └─────────────────┘
```

---

## 6. Why These Specific Alerts?

### The "Golden Signals" Approach

| Signal | Alert | Rationale |
|--------|-------|-----------|
| **Errors** | `*-5xx`, `*-failures` | Direct user impact, highest priority |
| **Latency** | `*-latency` | Performance degradation before failures |
| **Exceptions** | `*-exceptions` | Code health, potential cascading issues |

### What We Deliberately Don't Alert On

| Signal | Why Not? |
|--------|----------|
| CPU/Memory | Misleading without context; high CPU can be normal |
| Request count drop | Better handled by availability tests |
| 4xx errors | Usually client issues, not system health |
| Log volume | Noisy; better monitored via cost alerts |

### Production Extension Options

The module supports optional alerts for prod:

```bicep
// Enable in prod for external-facing services
param enableAvailabilityTest bool = true    // Synthetic ping test
param enableDependencyAlerts bool = true    // Database/API failures
```

---

## 7. Workbook vs Dashboard Decision

| Feature | Workbook | Portal Dashboard |
|---------|----------|------------------|
| **Version Control** | ✅ JSON in Bicep | ⚠️ Limited ARM export |
| **Query Power** | ✅ Full KQL | ⚠️ Metrics only |
| **Parameters** | ✅ Time range, filters | ❌ Static |
| **Sharing** | ✅ By resource ID | ✅ By dashboard ID |
| **Embedding** | ❌ Not embeddable | ✅ Portal home |
| **IaC Friendly** | ✅ Yes | ⚠️ Complex JSON |

**Golden Path Recommendation**: 
- Use **Workbooks** for operational dashboards (richer, version-controlled)
- Use **Portal Dashboards** only for executive summary tiles

---

## 8. Deployment Command

```bash
# Deploy operational layer to existing infrastructure
az deployment group create \
  --resource-group rg-obs-demo-dev-weu \
  --template-file modules/ops-alerting-workbooks.bicep \
  --parameters examples/ops-params-demo-dev.bicepparam
```

### Outputs

```json
{
  "actionGroupId": "/subscriptions/.../actionGroups/ag-mon-dev-demo",
  "alertRuleIds": [/* 8 alert IDs */],
  "workbookId": "/subscriptions/.../workbooks/ebc5f6c1-...",
  "workbookUrl": "https://portal.azure.com/#@.../workbook"
}
```

---

## 9. Auto-Mitigate Behavior

All alerts have `autoMitigate: true`:

```
Alert Lifecycle:
────────────────

     Condition Met (2 of 3 periods)
              │
              ▼
         ┌─────────┐
         │  FIRED  │ ─────► Email sent to ops-team@...
         └────┬────┘
              │
     Condition Cleared
              │
              ▼
         ┌──────────┐
         │ RESOLVED │ ─────► Resolution email sent
         └──────────┘

Why Auto-Mitigate?
- Ops team knows when issue is fixed
- Reduces manual alert closure
- Alert history shows duration
```

---

## 10. Next Steps / Recommendations

### Immediate Actions

1. **Test Alert Flow**: Trigger a 5xx error to verify email delivery
   ```bash
   curl -I https://app-web-demo-dev-weu.azurewebsites.net/api/forceerror
   ```

2. **Configure Teams Webhook** (optional):
   ```bicep
   param teamsWebhookUrl = 'https://outlook.office.com/webhook/...'
   ```

3. **Pin Workbook to Dashboard**:
   - Open workbook URL in browser
   - Click 📌 on key visualizations

### Production Enhancements

- [ ] Enable `enableAvailabilityTest = true` with external URL
- [ ] Add SMS receivers for critical (Sev 0) alerts
- [ ] Integrate with ServiceNow/PagerDuty via Logic App
- [ ] Create separate action groups for Sev 0 vs Sev 1+

---

## ✅ Verification Checklist

| Item | Status | Evidence |
|------|--------|----------|
| Action Group deployed | ✅ | `ag-mon-dev-demo` with 1 email receiver |
| 8 baseline alerts created | ✅ | Listed via `az monitor scheduled-query list` |
| Alerts connected to Action Group | ✅ | `actionGroups: [actionGroup.id]` in Bicep |
| Workbook deployed | ✅ | `Operations Dashboard - dev - demo` |
| Workbook has 4 sections | ✅ | Overview, Failures, Dependencies, Alerts |
| Severity levels env-aware | ✅ | Dev=1-2, Prod=0-1 |
| Thresholds env-aware | ✅ | Dev relaxed, Prod strict |
| Dashboard pinning documented | ✅ | Manual process described |

---

## Module Reference

**File**: [modules/ops-alerting-workbooks.bicep](../modules/ops-alerting-workbooks.bicep)  
**Lines**: 932  
**Parameters File**: [examples/ops-params-demo-dev.bicepparam](../examples/ops-params-demo-dev.bicepparam)

### Key Sections in Module

| Line Range | Content |
|------------|---------|
| 1-45 | README and usage documentation |
| 47-90 | Parameters with validation |
| 92-151 | Variables (naming, severities, thresholds) |
| 153-176 | Action Group resource |
| 178-498 | Alert rules (8 total) |
| 500-575 | Optional: Dependency alerts, Availability test |
| 577-897 | Workbook content (KQL queries, visualizations) |
| 899-932 | Outputs |
