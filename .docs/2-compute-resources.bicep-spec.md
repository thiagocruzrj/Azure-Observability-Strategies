# Step B — Create the Three Compute Resources

## Status: PENDING

Deploy via Bicep module: `modules/compute.bicep` (to be created)

---

## 1. Create App Service Plan (Linux)

| Property | Value |
|----------|-------|
| **Name** | `asp-obs-demo-dev-weu` |
| **OS** | Linux |
| **SKU** | B1 (Basic - suitable for demo) |
| **Region** | West Europe |

---

## 2. Create Web App (Linux App Service)

| Property | Value |
|----------|-------|
| **Name** | `web-obs-demo-dev-weu` |
| **Runtime** | .NET 9 |
| **Plan** | `asp-obs-demo-dev-weu` |

### App Settings

| Setting | Value |
|---------|-------|
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | Connection string from `appi-web-demo-dev-weu` |
| `Api__BaseUrl` | `https://api-obs-demo-dev-weu.azurewebsites.net` |

---

## 3. Create API App (Linux App Service)

| Property | Value |
|----------|-------|
| **Name** | `api-obs-demo-dev-weu` |
| **Runtime** | .NET 9 |
| **Plan** | `asp-obs-demo-dev-weu` |

### App Settings

| Setting | Value |
|---------|-------|
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | Connection string from `appi-api-demo-dev-weu` |
| `Function__BaseUrl` | `https://func-obs-demo-dev-weu.azurewebsites.net` |

---

## 4. Create Storage Account (for Functions)

| Property | Value |
|----------|-------|
| **Name** | `stobsdemodevweu` (globally unique) |
| **Region** | West Europe |
| **SKU** | Standard_LRS |
| **Kind** | StorageV2 |

---

## 5. Create Function App (.NET Isolated)

| Property | Value |
|----------|-------|
| **Name** | `func-obs-demo-dev-weu` |
| **Runtime** | .NET 8 Isolated (Functions v4) |
| **Hosting** | Consumption (Y1) |
| **Storage** | `stobsdemodevweu` |

> ⚠️ **Note**: Azure Functions isolated worker currently supports .NET 8 with v4 runtime. .NET 9 support requires newer SDK versions.

### App Settings

| Setting | Value |
|---------|-------|
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | Connection string from `appi-func-demo-dev-weu` |
| `AzureWebJobsStorage` | Connection string from storage account |
| `FUNCTIONS_WORKER_RUNTIME` | `dotnet-isolated` |

---

## Service Communication URLs

Configure these app settings for service-to-service calls:

| App | Setting | Value |
|-----|---------|-------|
| Web | `Api__BaseUrl` | `https://api-obs-demo-dev-weu.azurewebsites.net` |
| API | `Function__BaseUrl` | `https://func-obs-demo-dev-weu.azurewebsites.net` |

---

## Bicep Deployment

```bash
# Deploy compute resources (after monitoring resources exist)
az deployment group create \
  --resource-group rg-obs-demo-dev-weu \
  --template-file modules/compute.bicep \
  --parameters env=dev workload=obs-demo
```