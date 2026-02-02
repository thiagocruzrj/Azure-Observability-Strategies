# Step 6: Auto-Instrumentation & Workspace-Based Migration - Verification Brain Dump

> **Date:** February 2, 2026  
> **Resource Group:** `rg-obs-demo-dev-weu`  
> **Instrumentation Approach:** Azure Monitor OpenTelemetry Distro (Code-based)

---

## 🎯 Understanding "Auto-Instrumentation" Expectations

### The Terminology Problem

```
┌─────────────────────────────────────────────────────────────────────────────┐
│              WHAT CUSTOMERS MEAN BY "AUTO-INSTRUMENTATION"                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Option A: "TRUE" No-Code Auto-Instrumentation (Agent-Based)               │
│  ──────────────────────────────────────────────────────────────────────────│
│  • App Service Site Extension / Agent injection                            │
│  • Zero code changes - works with deployed binaries                        │
│  • Limited: Only HTTP, SQL, some dependencies                              │
│  • Legacy approach - being phased out                                       │
│  • ⚠️ Not recommended for new projects                                     │
│                                                                             │
│  Option B: "Minimal Code" Instrumentation (SDK-Based) ← WE USE THIS        │
│  ──────────────────────────────────────────────────────────────────────────│
│  • 1 NuGet package + 3 lines of code                                       │
│  • Full OTel standard compliance                                           │
│  • Auto-instruments: HTTP, SQL, Redis, Azure SDK, gRPC, etc.              │
│  • Custom spans/traces possible                                            │
│  • ✅ Recommended by Microsoft for .NET                                    │
│                                                                             │
│  Option C: Manual Instrumentation (Full Control)                           │
│  ──────────────────────────────────────────────────────────────────────────│
│  • Manual Activity/Span creation                                           │
│  • Full control over what's captured                                       │
│  • Most work, most flexibility                                             │
│  • Rarely needed except for custom scenarios                               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Our Implementation: Option B (Minimal Code)

We chose **Azure Monitor OpenTelemetry Distro** because:
- ✅ Industry-standard (OpenTelemetry)
- ✅ 3 lines of code to enable
- ✅ Auto-instruments common libraries (HttpClient, SQL, etc.)
- ✅ Works with .NET 9 (latest)
- ✅ Modern correlation (W3C TraceContext)
- ✅ Connection string-based (not deprecated instrumentation key)

---

## 🔍 Verification Commands (All Working)

### 1. Verify Workspace-Based App Insights

```bash
az monitor app-insights component show \
  --app appi-web-demo-dev-weu \
  --resource-group rg-obs-demo-dev-weu \
  --query "{name:name, workspaceResourceId:workspaceResourceId, ingestionMode:ingestionMode}" \
  -o json
```

**Output:**
```json
{
  "ingestionMode": "LogAnalytics",
  "name": "appi-web-demo-dev-weu",
  "workspaceResourceId": "/subscriptions/.../workspaces/law-obs-demo-dev-weu"
}
```

> **Key indicator:** `ingestionMode: "LogAnalytics"` = workspace-based (modern)  
> **Legacy would show:** `ingestionMode: "ApplicationInsights"` = classic (deprecated)

---

### 2. Verify Connection String (Not Instrumentation Key)

```bash
az webapp config appsettings list \
  --name web-obs-demo-dev-weu \
  --resource-group rg-obs-demo-dev-weu \
  --query "[?name=='APPLICATIONINSIGHTS_CONNECTION_STRING'].value" \
  -o tsv | head -c 50
```

**Output:**
```
InstrumentationKey=6f9a91c9-...;IngestionEndpoint=h
```

> We use **connection string** (contains endpoint info), not standalone instrumentation key.

---

### 3. Check App Service Extension Version (Auto-Instrumentation Agent)

```bash
az webapp config appsettings list \
  --name web-obs-demo-dev-weu \
  --resource-group rg-obs-demo-dev-weu \
  --query "[?name=='ApplicationInsightsAgent_EXTENSION_VERSION'].value" \
  -o tsv
```

**Output:**
```
~3
```

> **Note:** The extension is enabled (`~3`) but our code-based OTel distro takes precedence.  
> This provides fallback and additional platform telemetry.

---

### 4. Verify OTel Distro in Code

```bash
# Check NuGet package
grep -A1 "Azure.Monitor" demo/Demo.Web/Demo.Web.csproj
```

**Output:**
```xml
<!-- Azure Monitor OpenTelemetry Distro for ASP.NET Core -->
<PackageReference Include="Azure.Monitor.OpenTelemetry.AspNetCore" Version="1.3.0" />
```

```bash
# Check initialization code
grep -n "UseAzureMonitor\|AddOpenTelemetry" demo/Demo.Web/Program.cs
```

**Output:**
```
24:builder.Services.AddOpenTelemetry()
34:    .UseAzureMonitor(options =>
```

---

### 5. Verify All App Insights Are Workspace-Based

```bash
# Web
az monitor app-insights component show --app appi-web-demo-dev-weu --resource-group rg-obs-demo-dev-weu --query "ingestionMode" -o tsv

# API
az monitor app-insights component show --app appi-api-demo-dev-weu --resource-group rg-obs-demo-dev-weu --query "ingestionMode" -o tsv

# Function
az monitor app-insights component show --app appi-func-demo-dev-weu --resource-group rg-obs-demo-dev-weu --query "ingestionMode" -o tsv
```

**Output (all three):**
```
LogAnalytics
LogAnalytics
LogAnalytics
```

---

### 6. Compare Classic vs Workspace-Based

```bash
# Check if any App Insights are still classic
az monitor app-insights component list \
  --resource-group rg-obs-demo-dev-weu \
  --query "[].{name:name, ingestionMode:ingestionMode, hasWorkspace:(workspaceResourceId != null)}" \
  -o table
```

**Output:**
```
Name                    IngestionMode  HasWorkspace
----------------------  -------------  ------------
appi-func-demo-dev-weu  LogAnalytics   True
appi-web-demo-dev-weu   LogAnalytics   True
appi-api-demo-dev-weu   LogAnalytics   True
```

---

## 📊 Actual State Summary

### Instrumentation Approach Matrix

| Component | Approach | Package | Code Required | Auto-Instrumented |
|-----------|----------|---------|---------------|-------------------|
| **Demo.Web** | OTel Distro | `Azure.Monitor.OpenTelemetry.AspNetCore` | 3 lines | HttpClient, ASP.NET Core |
| **Demo.Api** | OTel Distro | `Azure.Monitor.OpenTelemetry.AspNetCore` | 3 lines | HttpClient, ASP.NET Core |
| **Demo.Func** | Worker SDK | `Microsoft.Azure.Functions.Worker.ApplicationInsights` | 1 line | HTTP triggers |

---

### The "3 Lines of Code" Implementation

```csharp
// Program.cs - This is ALL you need for full instrumentation

builder.Services.AddOpenTelemetry()
    .UseAzureMonitor(options =>
    {
        options.ConnectionString = Environment.GetEnvironmentVariable("APPLICATIONINSIGHTS_CONNECTION_STRING");
    });
```

**What this auto-instruments:**
- ✅ All incoming HTTP requests (ASP.NET Core)
- ✅ All outgoing HTTP calls (HttpClient)
- ✅ SQL queries (Microsoft.Data.SqlClient, System.Data.SqlClient)
- ✅ Redis calls (StackExchange.Redis)
- ✅ Azure SDK calls (Storage, Service Bus, etc.)
- ✅ gRPC calls
- ✅ Exceptions
- ✅ ILogger logs

---

### Workspace-Based vs Classic Comparison

| Feature | Classic (Deprecated) | Workspace-Based (Modern) |
|---------|---------------------|-------------------------|
| Data storage | App Insights own store | Log Analytics Workspace |
| KQL queries | Limited | Full LAW queries |
| Cross-resource queries | ❌ No | ✅ Yes |
| Data retention control | Per-App Insights | Per-table in LAW |
| Azure Sentinel integration | ❌ No | ✅ Yes |
| Cost management | Per-instance | Unified LAW billing |
| Deprecation | **March 2025** | Current standard |

---

### Migration Path for Existing Apps

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    MIGRATION TO WORKSPACE-BASED                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  If you have CLASSIC App Insights (ingestionMode: ApplicationInsights):    │
│                                                                             │
│  Step 1: Create workspace-based App Insights                                │
│  ──────────────────────────────────────────────────────────────────────────│
│  az monitor app-insights component create \                                 │
│    --app appi-new \                                                         │
│    --location westeurope \                                                  │
│    --resource-group rg-monitoring \                                         │
│    --workspace /subscriptions/.../workspaces/law-name                       │
│                                                                             │
│  Step 2: Update app configuration                                           │
│  ──────────────────────────────────────────────────────────────────────────│
│  az webapp config appsettings set \                                         │
│    --name myapp \                                                           │
│    --resource-group rg-app \                                                │
│    --settings APPLICATIONINSIGHTS_CONNECTION_STRING="<new-conn-string>"     │
│                                                                             │
│  Step 3: (Optional) Migrate historical data                                 │
│  ──────────────────────────────────────────────────────────────────────────│
│  - Classic data remains in old App Insights                                 │
│  - New data flows to LAW                                                    │
│  - Consider exporting classic data before deprecation                       │
│                                                                             │
│  Step 4: Decommission classic App Insights                                  │
│  ──────────────────────────────────────────────────────────────────────────│
│  az monitor app-insights component delete --app appi-old --resource-group rg│
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

### Addressing the "No Code" Expectation

**For customers who truly want "no code changes":**

```bash
# Enable App Service auto-instrumentation (agent-based)
az webapp config appsettings set \
  --name myapp \
  --resource-group rg \
  --settings \
    APPLICATIONINSIGHTS_CONNECTION_STRING="<conn-string>" \
    ApplicationInsightsAgent_EXTENSION_VERSION="~3"
```

**Limitations of agent-based approach:**
- ❌ Less control over what's captured
- ❌ No custom spans/traces
- ❌ Slower to adopt new OTel features
- ❌ Limited to supported frameworks
- ✅ Zero code changes
- ✅ Works with any .NET version

**Our recommendation:**

| Scenario | Approach | Why |
|----------|----------|-----|
| Greenfield project | OTel Distro (code) | Full control, modern |
| Brownfield, can modify code | OTel Distro (code) | Best long-term |
| Brownfield, can't modify code | Agent (no-code) | Acceptable trade-off |
| Legacy .NET Framework | Agent (no-code) | Only option |

---

## 🔧 Bicep: Workspace-Based App Insights

```bicep
// modules/appinsights.bicep - Always creates workspace-based

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: applicationType
    
    // This is what makes it workspace-based:
    WorkspaceResourceId: logAnalyticsWorkspaceId
    
    // Modern features
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
  tags: tags
}

// Output connection string (not instrumentation key)
output connectionString string = appInsights.properties.ConnectionString
```

---

## ✅ Step 6 Checklist Verification

| Requirement | Status | Evidence |
|-------------|--------|----------|
| **OTel Distro for Web/API** | ✅ | `Azure.Monitor.OpenTelemetry.AspNetCore v1.3.0` |
| **Workspace-based App Insights** | ✅ | `ingestionMode: "LogAnalytics"` on all 3 |
| **Connection string (not iKey)** | ✅ | `APPLICATIONINSIGHTS_CONNECTION_STRING` set |
| **Migration path documented** | ✅ | Classic → Workspace steps above |
| **"No code" option explained** | ✅ | Agent vs SDK comparison |

---

## 🎓 Addressing the Expectation Mismatch

### For Sales/Pre-Sales Conversations

> **Customer:** "We need auto-instrumentation with no code changes."
>
> **Response:** "We support two approaches:
> 1. **Agent-based (zero code):** Enable via App Service settings. Works with existing binaries. Limited customization.
> 2. **SDK-based (3 lines):** Add one NuGet package and 3 lines to Program.cs. Full OTel compliance. Recommended by Microsoft.
>
> Most customers today choose SDK-based because it's still minimal effort but gives full control over sampling, custom attributes, and correlation."

### For Engineering Conversations

> **Engineer:** "What does 'auto-instrumentation' actually do for us?"
>
> **Response:** "The Azure Monitor OTel Distro auto-instruments:
> - ASP.NET Core request/response pipeline
> - HttpClientFactory outbound calls
> - SQL queries (both providers)
> - Azure SDK calls (Storage, Service Bus, etc.)
>
> You get distributed tracing, dependencies, exceptions, and performance metrics without writing instrumentation code. The '3 lines' just wires it up."

---

## ✅ Step 6 Verification Complete

**Summary:**
- Azure Monitor OpenTelemetry Distro (code-based, 3 lines) ✅
- All App Insights are workspace-based (`ingestionMode: LogAnalytics`) ✅
- Connection string used (not deprecated instrumentation key) ✅
- Agent-based "no code" option documented for brownfield ✅
- Migration path from classic to workspace-based documented ✅
- Expectation mismatch addressed with clear comparison ✅
