# Step D — Deploy Apps + Verify Dependency Map

## ✅ Status: PARTIALLY COMPLETED

- ✅ Web App deployed and working
- ✅ API App deployed and working
- ⚠️ Function App deployment issues (404 on endpoints)
- ✅ Web → API distributed tracing verified

Demo application: `demo/` folder with 3-service distributed tracing

---

## 1. Deploy Web + API + Function Code

### Deployment Options

| Method | Command |
|--------|---------|
| **VS Code** | Right-click project → Deploy to Web App |
| **Azure CLI** | `az webapp deploy` / `func azure functionapp publish` |
| **GitHub Actions** | Use `.github/workflows/` pipeline |
| **Zip Deploy** | `az webapp deployment source config-zip` |

### Code Requirements

Ensure proper distributed tracing setup:

| Service | Requirements |
|---------|--------------|
| **Web** | Uses `HttpClientFactory` to call API |
| **API** | Uses `HttpClientFactory` to call Function |
| **Function** | .NET Isolated with `telemetryMode: OpenTelemetry` |

### Demo Project Structure

```
demo/
├── Demo.Web/           # ASP.NET Core (net9.0) - Port 5001
├── Demo.Api/           # ASP.NET Core (net9.0) - Port 5002
├── Demo.Func/          # Azure Functions Isolated (net8.0) - Port 7073
├── DistributedTracingDemo.sln
├── global.json
├── run-all.ps1
└── README.md
```

---

## 2. Run End-to-End Request

### Local Testing

```powershell
# Terminal 1: Start Function
cd demo/Demo.Func && func start

# Terminal 2: Start API
cd demo/Demo.Api && dotnet run

# Terminal 3: Start Web
cd demo/Demo.Web && dotnet run

# Terminal 4: Test the flow
curl http://localhost:5001/demo
```

### Azure Testing

```bash
# Hit the web endpoint
curl https://web-obs-demo-dev-weu.azurewebsites.net/demo
```

### Expected Response

```json
{
  "service": "Demo.Web",
  "traceId": "abc123...",
  "orderId": "guid-here",
  "timestamp": "2026-02-02T12:00:00Z",
  "apiResponse": {
    "service": "Demo.Api",
    "orderId": "guid-here",
    "status": "processed",
    "enrichment": {
      "service": "Demo.Func",
      "orderId": "guid-here",
      "enrichedAt": "2026-02-02T12:00:00Z",
      "metadata": { "priority": "normal", "region": "weu" }
    }
  }
}
```

---

## 3. Verify Correlation in Application Insights 🎯

### Application Map (The "Wow Moment")

1. Go to Azure Portal → Application Insights (`appi-web-demo-dev-weu`)
2. Click **Application Map** in left menu
3. You should see: **Web → API → Function**

![Application Map showing distributed trace flow](https://learn.microsoft.com/en-us/azure/azure-monitor/app/media/app-map/app-map.png)

### Transaction Search

1. Go to **Transaction search**
2. Filter by `GET /demo`
3. Click a request to see **End-to-end transaction details**
4. Verify spans show:
   - Web request (parent)
   - HTTP dependency to API (child)
   - API request
   - HTTP dependency to Function (grandchild)
   - Function execution

### KQL Query for Verification

```kusto
// Find distributed traces across all 3 services
union requests, dependencies
| where timestamp > ago(1h)
| where operation_Id != ""
| summarize 
    Services = make_set(cloud_RoleName),
    RequestCount = countif(itemType == "request"),
    DependencyCount = countif(itemType == "dependency")
  by operation_Id
| where array_length(Services) >= 2
| order by RequestCount desc
| take 20
```

---

## 4. Optional: Storage Dependency

If Function calls Azure Blob Storage:

1. Set environment variable: `ENABLE_STORAGE_DEPENDENCY=true`
2. Configure `STORAGE_CONNECTION_STRING`
3. You'll see an extra **Blob Storage** node in the Application Map
