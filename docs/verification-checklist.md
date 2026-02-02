# Monitoring Golden Path - Verification Checklist

> **Project**: Azure Observability Strategies  
> **Date**: February 2, 2026  
> **Environment**: `rg-obs-demo-dev-weu` (West Europe)

---

## Executive Summary

| Step | Topic | Status | Documentation |
|------|-------|--------|---------------|
| 1 | Monitoring Strategy | ✅ Complete | [step1-monitoring-strategy-verification.md](step1-monitoring-strategy-verification.md) |
| 2 | Naming & Tags | ✅ Complete | [step2-naming-tags-verification.md](step2-naming-tags-verification.md) |
| 3 | Tracing & Dependencies | ✅ Complete | [step3-tracing-dependencies-verification.md](step3-tracing-dependencies-verification.md) |
| 4 | Sampling | ✅ Complete | [step4-sampling-verification.md](step4-sampling-verification.md) |
| 5 | Retention & Costs | ✅ Complete | [step5-retention-costs-verification.md](step5-retention-costs-verification.md) |
| 6 | Auto-Instrumentation | ✅ Complete | [step6-auto-instrumentation-verification.md](step6-auto-instrumentation-verification.md) |
| 7 | Governance & Security | ✅ Complete | [step7-governance-security-verification.md](step7-governance-security-verification.md) |
| 8 | Operational Layer | ✅ Complete | [step8-operational-layer-verification.md](step8-operational-layer-verification.md) |

---

## ✅ Completed Checks

### Step 1: Monitoring Strategy

| Check | Status | Evidence |
|-------|--------|----------|
| Log Analytics Workspace deployed | ✅ | `law-obs-demo-dev-weu` |
| Workspace-based App Insights (3x) | ✅ | `appi-web/api/func-demo-dev-weu` |
| All App Insights use `ingestionMode: LogAnalytics` | ✅ | Verified via `az monitor app-insights component show` |
| Single LAW for unified querying | ✅ | All 3 App Insights → same LAW |
| Diagnostic settings enabled | ✅ | App Service → LAW (platform logs) |
| Golden Path module structure documented | ✅ | [MODULE-STRUCTURE.md](../MODULE-STRUCTURE.md) |

**Key Command:**
```bash
az monitor app-insights component show --app appi-web-demo-dev-weu -g rg-obs-demo-dev-weu --query "ingestionMode"
# Result: "LogAnalytics"
```

---

### Step 2: Naming Conventions & Tags

| Check | Status | Evidence |
|-------|--------|----------|
| Naming pattern: `{type}-{workload}-{env}-{region}` | ✅ | All resources follow pattern |
| 4 required tags enforced | ✅ | `env`, `workload`, `owner`, `costCenter` |
| Azure Policy deployed | ✅ | `assign-require-tags-dev-obs-demo` |
| Policy in Audit mode (not Deny) | ✅ | `enforcementMode: Default` |
| 9/9 resources compliant | ✅ | All resources have required tags |

**Key Command:**
```bash
az policy state summarize --resource-group rg-obs-demo-dev-weu
# Result: 9 compliant, 0 non-compliant
```

---

### Step 3: Tracing & Dependencies

| Check | Status | Evidence |
|-------|--------|----------|
| W3C TraceContext propagation | ✅ | `traceparent` header verified |
| End-to-end trace: Web → API → Function | ✅ | TraceId: `c70d31d239107c645c8c194f3478e6a0` |
| Dependency auto-collection | ✅ | HTTP, SQL dependencies captured |
| `cloud_RoleName` set per component | ✅ | Web, API, Function distinguished |
| OTel distro v1.3.0 configured | ✅ | `Azure.Monitor.OpenTelemetry.AspNetCore` |
| Functions OTel mode enabled | ✅ | `OTEL_RESOURCE_ATTRIBUTES` set |

**Key Command:**
```bash
az monitor app-insights query --app appi-web-demo-dev-weu --analytics-query "
  requests | where operation_Id == 'c70d31d2...' | project cloud_RoleName, name"
```

---

### Step 4: Sampling

| Check | Status | Evidence |
|-------|--------|----------|
| Dev sampling: 100% (no sampling) | ✅ | `OTEL_TRACES_SAMPLER_ARG=1.0` |
| Prod sampling: 10% default | ✅ | Documented in config |
| Adaptive sampling disabled for OTel | ✅ | Using head-based sampling |
| Sampling preserves trace correlation | ✅ | Parent-based sampling |
| Cost vs quality tradeoff documented | ✅ | Step 4 doc explains "why" |

**Key Insight:** Sampling decision made at trace start, all spans in same trace follow same decision.

---

### Step 5: Retention & Costs

| Check | Status | Evidence |
|-------|--------|----------|
| LAW retention: 30 days (dev) | ✅ | `retentionInDays: 30` |
| PerGB2018 pricing tier | ✅ | Pay-per-GB model |
| Per-table retention demonstrated | ✅ | `AppDependencies` → 30 days |
| Diagnostic categories documented | ✅ | 5/7 enabled with rationale |
| Cost projection formulas provided | ✅ | GB/day × $2.30 × 30 |

**Key Command:**
```bash
az monitor log-analytics workspace table update \
  --resource-group rg-obs-demo-dev-weu \
  --workspace-name law-obs-demo-dev-weu \
  --name AppDependencies \
  --retention-time 30
```

---

### Step 6: Auto-Instrumentation

| Check | Status | Evidence |
|-------|--------|----------|
| OTel distro approach (SDK-based) | ✅ | 3 lines in Program.cs |
| Not using agent-based approach | ✅ | Documented as intentional |
| Workspace-based migration complete | ✅ | All App Insights workspace-based |
| Connection string injection | ✅ | Via App Settings |
| Functions isolated worker configured | ✅ | .NET 8 isolated + OTel |

**Key Code:**
```csharp
builder.Services.AddOpenTelemetry()
    .UseAzureMonitor();
```

---

### Step 7: Governance & Security

| Check | Status | Evidence |
|-------|--------|----------|
| RBAC roles defined | ✅ | Monitoring Reader + Contributor |
| PII policy documented | ✅ | 400+ lines in security-observability.bicep |
| Safe logging patterns demonstrated | ✅ | Demo.Web/Program.cs verified |
| Data residency: EU (westeurope) | ✅ | LAW + App Insights in westeurope |
| Retention-based GDPR compliance | ✅ | 30-day auto-purge strategy |
| Right to erasure strategy | ✅ | Prevention + short retention |

**Key Insight:** LAW doesn't support individual record deletion, so strategy is:
1. Never log PII
2. Use pseudonymization (internal IDs)
3. Auto-purge via retention

---

### Step 8: Operational Layer

| Check | Status | Evidence |
|-------|--------|----------|
| Action Group deployed | ✅ | `ag-mon-dev-demo` |
| Email receiver configured | ✅ | `ops-team@contoso.com` |
| 8 baseline alerts created | ✅ | 5xx, latency, exceptions |
| Alerts scoped to App Insights | ✅ | Per-component targeting |
| Severity levels env-aware | ✅ | Dev=1-2, Prod=0-1 |
| Thresholds env-aware | ✅ | Dev relaxed, Prod strict |
| Workbook deployed | ✅ | "Operations Dashboard - dev - demo" |
| Workbook has 4 sections | ✅ | Overview, Failures, Dependencies, Alerts |
| Auto-mitigate enabled | ✅ | Alerts auto-resolve |
| Dashboard pinning documented | ✅ | Manual process in doc |

**Key Command:**
```bash
az monitor scheduled-query list -g rg-obs-demo-dev-weu --query "[].name" -o tsv
# Result: 8 alert rules
```

---

## ⚠️ Remaining Checks / Recommendations

### High Priority

| Check | Status | Recommendation |
|-------|--------|----------------|
| **Test alert notification flow** | ⬜ TODO | Trigger 5xx error, verify email received |
| **Verify workbook visualizations** | ⬜ TODO | Open workbook URL, check all charts render |
| **RBAC role assignments** | ⬜ TODO | Assign actual AAD group IDs in prod |
| **Production deployment** | ⬜ TODO | Deploy to `rg-obs-demo-prod-weu` |

### Medium Priority

| Check | Status | Recommendation |
|-------|--------|----------------|
| **Availability test** | ⬜ Optional | Enable `enableAvailabilityTest=true` for prod |
| **Teams webhook** | ⬜ Optional | Add `teamsWebhookUrl` for real-time alerts |
| **Dependency alerts** | ⬜ Optional | Enable `enableDependencyAlerts=true` for prod |
| **Budget alerts** | ⬜ TODO | Set Azure Cost Management budget for LAW costs |
| **Uncommit ops module in main.bicep** | ⬜ TODO | Integrate into main deployment |

### Low Priority / Nice-to-Have

| Check | Status | Recommendation |
|-------|--------|----------------|
| **Custom metrics** | ⬜ Optional | Add business-specific metrics |
| **Log-based metrics** | ⬜ Optional | Create metrics from log queries |
| **Grafana integration** | ⬜ Optional | Azure Managed Grafana for dashboards |
| **PagerDuty/ServiceNow** | ⬜ Optional | Add Logic App for ticket creation |
| **Chaos engineering** | ⬜ Optional | Test alert thresholds with fault injection |

---

## Deployed Resources Summary

```
rg-obs-demo-dev-weu/
│
├── 📊 MONITORING FOUNDATION
│   ├── law-obs-demo-dev-weu         (Log Analytics Workspace)
│   ├── appi-web-demo-dev-weu        (Application Insights - Web)
│   ├── appi-api-demo-dev-weu        (Application Insights - API)
│   └── appi-func-demo-dev-weu       (Application Insights - Functions)
│
├── 🖥️ COMPUTE
│   ├── asp-demo-dev-weu             (App Service Plan)
│   ├── app-web-demo-dev-weu         (Web App - .NET 9)
│   ├── app-api-demo-dev-weu         (API App - .NET 9)
│   ├── func-demo-dev-weu            (Function App - .NET 8 isolated)
│   └── stdemodevweu                 (Storage Account - for Functions)
│
├── 🏷️ GOVERNANCE
│   └── assign-require-tags-dev-obs-demo (Azure Policy Assignment)
│
└── 🔔 OPERATIONAL LAYER
    ├── ag-mon-dev-demo              (Action Group)
    ├── alrt-dev-demo-web-5xx        (Alert Rule)
    ├── alrt-dev-demo-api-5xx        (Alert Rule)
    ├── alrt-dev-demo-web-latency    (Alert Rule)
    ├── alrt-dev-demo-api-latency    (Alert Rule)
    ├── alrt-dev-demo-web-exceptions (Alert Rule)
    ├── alrt-dev-demo-api-exceptions (Alert Rule)
    ├── alrt-dev-demo-func-failures  (Alert Rule)
    ├── alrt-dev-demo-func-exceptions(Alert Rule)
    └── ebc5f6c1-... (workbook)      (Operations Dashboard)
```

---

## Files Created During Verification

| File | Purpose |
|------|---------|
| `docs/step1-monitoring-strategy-verification.md` | Strategy brain dump |
| `docs/step2-naming-tags-verification.md` | Naming/tags brain dump |
| `docs/step3-tracing-dependencies-verification.md` | Tracing brain dump |
| `docs/step4-sampling-verification.md` | Sampling brain dump |
| `docs/step5-retention-costs-verification.md` | Retention/costs brain dump |
| `docs/step6-auto-instrumentation-verification.md` | Auto-instrumentation brain dump |
| `docs/step7-governance-security-verification.md` | Governance/security brain dump |
| `docs/step8-operational-layer-verification.md` | Operational layer brain dump |
| `docs/verification-checklist.md` | This file (master checklist) |
| `MODULE-STRUCTURE.md` | IaC module architecture |
| `scripts/verify-tracing.sh` | Repeatable trace verification |
| `examples/ops-params-demo-dev.bicepparam` | Ops layer deployment params |

---

## Quick Verification Commands

### Health Check (Run All)

```bash
# 1. Check all resources exist
az resource list -g rg-obs-demo-dev-weu --query "[].{name:name, type:type}" -o table

# 2. Check App Insights connection
az monitor app-insights component show --app appi-web-demo-dev-weu -g rg-obs-demo-dev-weu \
  --query "{name:name, ingestionMode:ingestionMode, connectionString:connectionString}" -o json

# 3. Check alerts are enabled
az monitor scheduled-query list -g rg-obs-demo-dev-weu \
  --query "[].{name:name, enabled:enabled}" -o table

# 4. Check policy compliance
az policy state summarize -g rg-obs-demo-dev-weu \
  --query "{compliant:results.resourceDetails[0].compliantResources, nonCompliant:results.resourceDetails[0].nonCompliantResources}"

# 5. Check action group
az monitor action-group show -g rg-obs-demo-dev-weu -n ag-mon-dev-demo \
  --query "{name:name, enabled:enabled, emailCount:length(emailReceivers)}" -o json
```

### Generate Traffic for Testing

```bash
# Web app endpoint
curl https://app-web-demo-dev-weu.azurewebsites.net/

# API endpoint (through web)
curl https://app-web-demo-dev-weu.azurewebsites.net/api/orders

# Direct API call
curl https://app-api-demo-dev-weu.azurewebsites.net/api/inventory

# Trigger Function (if HTTP triggered)
curl https://func-demo-dev-weu.azurewebsites.net/api/process
```

---

## Next Steps

1. **Run TODO checks** listed in "Remaining Checks" section
2. **Commit changes** to git repository
3. **Deploy to production** with stricter thresholds
4. **Set up CI/CD** to deploy IaC on merge
5. **Document runbooks** for common alert scenarios

---

## Module Completion Status

| Module | File | Lines | Status |
|--------|------|-------|--------|
| Foundation | `modules/foundation.bicep` | ~200 | ✅ Deployed |
| App Insights | `modules/appinsights.bicep` | ~150 | ✅ Deployed |
| Policy Tags | `modules/policy-tags.bicep` | ~100 | ✅ Deployed |
| Security/RBAC | `modules/security-observability.bicep` | ~415 | 📝 Documented (deploy with AAD IDs) |
| Ops Layer | `modules/ops-alerting-workbooks.bicep` | ~930 | ✅ Deployed |

---

*Last updated: February 2, 2026*
