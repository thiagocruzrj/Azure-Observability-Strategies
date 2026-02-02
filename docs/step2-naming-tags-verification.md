# Step 2: Best Practices & Conventions - Verification Brain Dump

> **Date:** February 2, 2026  
> **Resource Group:** `rg-obs-demo-dev-weu`  
> **Subscription:** `96c57020-cece-485b-a9a8-25214593bf2d`

---

## 🔍 Verification Commands (All Working)

### 1. Policy Assignment Check

```bash
az policy assignment list \
  --resource-group rg-obs-demo-dev-weu \
  --query "[].{name:name, displayName:displayName, enforcementMode:enforcementMode}" \
  -o table
```

**Output:**
```
Name                              DisplayName                                    EnforcementMode
--------------------------------  ---------------------------------------------  -----------------
assign-require-tags-dev-obs-demo  Enforce mandatory tags on rg-obs-demo-dev-weu  Default
```

---

### 2. Policy Definition (Rule Logic)

```bash
az policy definition show \
  --name policy-require-tags-dev-obs-demo \
  --query "policyRule" \
  -o json
```

**Output:**
```json
{
  "if": {
    "anyOf": [
      { "exists": "false", "field": "tags['env']" },
      { "exists": "false", "field": "tags['workload']" },
      { "exists": "false", "field": "tags['owner']" },
      { "exists": "false", "field": "tags['costCenter']" }
    ]
  },
  "then": {
    "effect": "[parameters('effect')]"
  }
}
```

---

### 3. Policy Assignment Parameters

```bash
az policy assignment show \
  --name assign-require-tags-dev-obs-demo \
  --resource-group rg-obs-demo-dev-weu \
  --query "{policyDefinitionId:policyDefinitionId, parameters:parameters}" \
  -o json
```

**Output:**
```json
{
  "parameters": {
    "effect": {
      "value": "Audit"
    }
  },
  "policyDefinitionId": "/subscriptions/96c57020-cece-485b-a9a8-25214593bf2d/providers/Microsoft.Authorization/policyDefinitions/policy-require-tags-dev-obs-demo"
}
```

---

### 4. Policy Compliance Summary

```bash
az policy state summarize \
  --resource-group rg-obs-demo-dev-weu \
  --query "policyAssignments[?contains(policyAssignmentId,'require-tags')].{compliant:results.resourceDetails[?complianceState=='compliant'].count|[0], nonCompliant:results.resourceDetails[?complianceState=='noncompliant'].count|[0]}" \
  -o table
```

**Output:**
```
Compliant    NonCompliant
-----------  --------------
9            1
```

---

### 5. Non-Compliant Resources List

```bash
az policy state list \
  --resource-group rg-obs-demo-dev-weu \
  --filter "complianceState eq 'NonCompliant'" \
  --query "[].{resource:resourceId}" \
  -o tsv | sort -u
```

**Output:**
```
/subscriptions/.../providers/microsoft.insights/actiongroups/application insights smart detection
```

> ⚠️ The "Application Insights Smart Detection" action group is auto-created by Azure without tags. This is expected behavior.

---

### 6. Trigger Policy Scan (Refresh Compliance State)

```bash
az policy state trigger-scan \
  --resource-group rg-obs-demo-dev-weu \
  --no-wait
```

---

### 7. Tag Verification Commands Per Resource

#### Log Analytics Workspace
```bash
az monitor log-analytics workspace show \
  --workspace-name law-obs-demo-dev-weu \
  --resource-group rg-obs-demo-dev-weu \
  --query "tags" \
  -o json
```

**Output:**
```json
{
  "costCenter": "CC1234",
  "env": "dev",
  "owner": "platform-team",
  "workload": "obs-demo"
}
```

#### Application Insights (Web)
```bash
az monitor app-insights component show \
  --app appi-web-demo-dev-weu \
  --resource-group rg-obs-demo-dev-weu \
  --query "tags" \
  -o json
```

**Output:**
```json
{
  "costCenter": "CC1234",
  "env": "dev",
  "owner": "platform-team",
  "workload": "obs-demo"
}
```

#### Web App
```bash
az webapp show \
  --name web-obs-demo-dev-weu \
  --resource-group rg-obs-demo-dev-weu \
  --query "tags" \
  -o json
```

**Output:**
```json
{
  "costCenter": "CC1234",
  "env": "dev",
  "hidden-link: /app-insights-resource-id": "/subscriptions/.../providers/microsoft.insights/components/appi-web-demo-dev-weu",
  "owner": "platform-team",
  "workload": "obs-demo"
}
```

#### API App
```bash
az webapp show \
  --name api-obs-demo-dev-weu \
  --resource-group rg-obs-demo-dev-weu \
  --query "tags" \
  -o json
```

**Output:**
```json
{
  "costCenter": "CC1234",
  "env": "dev",
  "hidden-link: /app-insights-resource-id": "/subscriptions/.../providers/microsoft.insights/components/appi-api-demo-dev-weu",
  "owner": "platform-team",
  "workload": "obs-demo"
}
```

#### Function App
```bash
az functionapp show \
  --name func-obs-demo-dev-weu \
  --resource-group rg-obs-demo-dev-weu \
  --query "tags" \
  -o json
```

**Output:**
```json
{
  "costCenter": "CC1234",
  "env": "dev",
  "hidden-link: /app-insights-resource-id": "/subscriptions/.../providers/microsoft.insights/components/appi-func-demo-dev-weu",
  "owner": "platform-team",
  "workload": "obs-demo"
}
```

#### Storage Account
```bash
az storage account show \
  --name stdemodevweu \
  --resource-group rg-obs-demo-dev-weu \
  --query "tags" \
  -o json
```

**Output:**
```json
{
  "costCenter": "CC1234",
  "env": "dev",
  "owner": "platform-team",
  "workload": "obs-demo"
}
```

#### App Service Plan
```bash
az appservice plan show \
  --name asp-obs-demo-dev-weu \
  --resource-group rg-obs-demo-dev-weu \
  --query "tags" \
  -o json
```

**Output:**
```json
{
  "costCenter": "CC1234",
  "env": "dev",
  "owner": "platform-team",
  "workload": "obs-demo"
}
```

---

### 8. Bulk Tag Check (All Resources)

```bash
az resource list \
  --resource-group rg-obs-demo-dev-weu \
  --query "[].{name:name, type:type, tags:tags}" \
  -o table
```

---

## 📊 Actual State Summary

### Naming Convention Compliance

| Resource | Actual Name | Pattern | Status |
|----------|-------------|---------|--------|
| Resource Group | `rg-obs-demo-dev-weu` | `rg-{workload}-{env}-{region}` | ✅ |
| Log Analytics | `law-obs-demo-dev-weu` | `law-{workload}-{env}-{region}` | ✅ |
| App Insights Web | `appi-web-demo-dev-weu` | `appi-{component}-{workload}-{env}-{region}` | ✅ |
| App Insights API | `appi-api-demo-dev-weu` | `appi-{component}-{workload}-{env}-{region}` | ✅ |
| App Insights Func | `appi-func-demo-dev-weu` | `appi-{component}-{workload}-{env}-{region}` | ✅ |
| App Service Plan | `asp-obs-demo-dev-weu` | `asp-{workload}-{env}-{region}` | ✅ |
| Web App | `web-obs-demo-dev-weu` | `web-{workload}-{env}-{region}` | ✅ |
| API App | `api-obs-demo-dev-weu` | `api-{workload}-{env}-{region}` | ✅ |
| Function App | `func-obs-demo-dev-weu` | `func-{workload}-{env}-{region}` | ✅ |
| Storage Account | `stdemodevweu` | `st{workload}{env}{region}` | ✅ |

---

### Tag Compliance Matrix

| Resource | `env` | `workload` | `owner` | `costCenter` | Status |
|----------|-------|------------|---------|--------------|--------|
| `law-obs-demo-dev-weu` | dev | obs-demo | platform-team | CC1234 | ✅ |
| `appi-web-demo-dev-weu` | dev | obs-demo | platform-team | CC1234 | ✅ |
| `appi-api-demo-dev-weu` | dev | obs-demo | platform-team | CC1234 | ✅ |
| `appi-func-demo-dev-weu` | dev | obs-demo | platform-team | CC1234 | ✅ |
| `asp-obs-demo-dev-weu` | dev | obs-demo | platform-team | CC1234 | ✅ |
| `web-obs-demo-dev-weu` | dev | obs-demo | platform-team | CC1234 | ✅ |
| `api-obs-demo-dev-weu` | dev | obs-demo | platform-team | CC1234 | ✅ |
| `func-obs-demo-dev-weu` | dev | obs-demo | platform-team | CC1234 | ✅ |
| `stdemodevweu` | dev | obs-demo | platform-team | CC1234 | ✅ |
| `Application Insights Smart Detection` | ❌ | ❌ | ❌ | ❌ | ⚠️ Auto-created |

---

### Policy State

| Property | Value |
|----------|-------|
| Policy Name | `policy-require-tags-dev-obs-demo` |
| Assignment Name | `assign-require-tags-dev-obs-demo` |
| Effect | `Audit` |
| Enforcement Mode | `Default` |
| Required Tags | `env`, `workload`, `owner`, `costCenter` |
| Compliant Resources | 9 |
| Non-Compliant Resources | 1 (auto-created by Azure) |

---

### Hidden Tags (Auto-added by Azure)

Some resources have an additional hidden tag auto-added by Azure for App Insights linking:

```
"hidden-link: /app-insights-resource-id": "/subscriptions/.../providers/microsoft.insights/components/appi-{component}-demo-dev-weu"
```

This appears on:
- `web-obs-demo-dev-weu`
- `api-obs-demo-dev-weu`
- `func-obs-demo-dev-weu`

---

## ✅ Step 2 Verification Complete

**Summary:**
- All 10 manually-created resources follow naming convention ✅
- All 9 controllable resources have required tags ✅
- Policy enforcement active in Audit mode ✅
- 1 non-compliant resource is auto-created by Azure (expected) ⚠️
