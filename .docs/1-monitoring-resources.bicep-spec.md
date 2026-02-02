# Step A — Create Shared Monitoring Resources

## ✅ Status: COMPLETED

All resources deployed via Bicep: `main.bicep` with `parameters/dev.bicepparam`

---

## 1. Create Resource Group

| Property | Value |
|----------|-------|
| **Name** | `rg-obs-demo-dev-weu` |
| **Region** | West Europe |
| **Tags** | `env=dev`, `workload=obs-demo`, `owner=platform-team`, `costCenter=CC1234` |

---

## 2. Create Log Analytics Workspace (LAW)

| Property | Value |
|----------|-------|
| **Name** | `law-obs-demo-dev-weu` |
| **Resource Group** | `rg-obs-demo-dev-weu` |
| **Retention** | 30 days (PerGB2018 SKU minimum) |
| **SKU** | PerGB2018 |

> ⚠️ **Note**: The spec suggested 14 days, but Azure's PerGB2018 SKU requires **minimum 30 days**.

---

## 3. Create 3 Workspace-Based Application Insights

Create each as **workspace-based** and attach to the LAW:

| Component | Name | Status |
|-----------|------|--------|
| Web | `appi-web-demo-dev-weu` | ✅ Created |
| API | `appi-api-demo-dev-weu` | ✅ Created |
| Function | `appi-func-demo-dev-weu` | ✅ Created |

---

## 4. Connection Strings

Retrieve connection strings for app settings:

```bash
# Web
az monitor app-insights component show --app appi-web-demo-dev-weu -g rg-obs-demo-dev-weu --query connectionString -o tsv

# API
az monitor app-insights component show --app appi-api-demo-dev-weu -g rg-obs-demo-dev-weu --query connectionString -o tsv

# Function
az monitor app-insights component show --app appi-func-demo-dev-weu -g rg-obs-demo-dev-weu --query connectionString -o tsv
```

> ✅ **Best Practice**: Use connection strings everywhere (NOT instrumentation keys)

---

## Deployment Command

```bash
az deployment sub create \
  --location westeurope \
  --template-file main.bicep \
  --parameters parameters/dev.bicepparam \
  --name "monitoring-golden-path-dev"
```