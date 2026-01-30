# Sampling, Retention & Cost Controls Standard

> **Internal Engineering Standard** | Version 1.0 | January 2026  
> **Goal**: Sustainable observability — maximize signal, minimize noise and cost

---

## Overview

Observability at scale requires intentional choices about **what to keep**, **how long to keep it**, and **how much to sample**. Uncontrolled telemetry leads to:

- 💸 **Exploding costs** — Azure Monitor charges per GB ingested
- 🔇 **Signal buried in noise** — Important events lost in verbose logging
- 🐌 **Slow queries** — Large data volumes degrade Log Analytics performance

This standard establishes defaults for the Monitoring Golden Path.

---

## 1. Log Analytics Workspace Retention

### Retention Defaults

| Environment | Retention (Days) | Rationale |
|-------------|------------------|-----------|
| **Development** | 14 | Short debugging cycles; data rarely needed beyond 2 weeks |
| **Production** | 30 | Incident investigation, compliance, trend analysis |

### Bicep Configuration

```bicep
@description('Log Analytics Workspace retention in days')
@minValue(7)
@maxValue(730)
param logRetentionDays int = 30

// In foundation module or LAW resource:
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: workspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: logRetentionDays  // Workspace-level default
    // Per-table retention can override this (see "Tuning Later" section)
  }
}
```

### Parameters by Environment

```bicep
// parameters/dev.bicepparam
param logRetentionDays = 14

// parameters/prod.bicepparam
param logRetentionDays = 30
```

### Why These Defaults?

| Consideration | Dev | Prod |
|---------------|-----|------|
| Debugging window | Days | Weeks |
| Incident response | N/A | 30-day lookback typical |
| Cost sensitivity | Lower volume | Higher volume, cost matters |
| Compliance requirements | None | May require 30-90 days |
| Free tier | 31 days included | 31 days included |

> 📖 [Log Analytics data retention and archive](https://learn.microsoft.com/azure/azure-monitor/logs/data-retention-configure)

---

## 2. Application Insights Sampling

### Sampling Defaults

| Environment | Sampling Ratio | Effective Rate | Rationale |
|-------------|----------------|----------------|-----------|
| **Development** | `1.0` | 100% | Full visibility for debugging |
| **Production** | `0.1` | 10% | Cost control; statistically significant |

### ASP.NET Core Configuration (Program.cs)

```csharp
using Azure.Monitor.OpenTelemetry.AspNetCore;
using OpenTelemetry.Resources;

var builder = WebApplication.CreateBuilder(args);

// ============================================================================
// Sampling Configuration
// ============================================================================

// Priority: Environment variable > appsettings.{Environment}.json > appsettings.json
var samplingRatio = float.TryParse(
    Environment.GetEnvironmentVariable("OTEL_SAMPLING_RATIO"),
    out var envSampling)
    ? envSampling
    : builder.Configuration.GetValue<float>("AzureMonitor:SamplingRatio", 1.0f);

// ============================================================================
// OpenTelemetry with Azure Monitor
// ============================================================================

builder.Services.AddOpenTelemetry()
    .ConfigureResource(resource => resource
        .AddService(
            serviceName: builder.Configuration["ServiceInfo:Name"] ?? "unknown",
            serviceVersion: builder.Configuration["ServiceInfo:Version"] ?? "0.0.0")
        .AddAttributes(new Dictionary<string, object>
        {
            ["deployment.environment"] = builder.Environment.EnvironmentName.ToLowerInvariant()
        }))
    .UseAzureMonitor(options =>
    {
        // Connection string ONLY - no instrumentation keys
        options.ConnectionString = Environment.GetEnvironmentVariable("APPLICATIONINSIGHTS_CONNECTION_STRING")
            ?? builder.Configuration["ApplicationInsights:ConnectionString"];
        
        // Fixed-rate sampling
        // W3C TraceContext propagation is enabled by default (preserves end-to-end traces)
        options.SamplingRatio = samplingRatio;
    });

var app = builder.Build();
app.Run();
```

### appsettings Configuration

**appsettings.json** (default for all environments):

```json
{
  "AzureMonitor": {
    "SamplingRatio": 1.0
  },
  "ServiceInfo": {
    "Name": "web-demoapp",
    "Version": "1.0.0"
  }
}
```

**appsettings.Development.json**:

```json
{
  "AzureMonitor": {
    "SamplingRatio": 1.0
  }
}
```

**appsettings.Production.json**:

```json
{
  "AzureMonitor": {
    "SamplingRatio": 0.1
  }
}
```

### Sampling Behavior

| Aspect | Behavior |
|--------|----------|
| **Trace preservation** | Entire trace sampled in/out together (no broken traces) |
| **Correlation** | W3C `traceparent` header propagates automatically |
| **Dependencies** | Sampled with parent request |
| **Metrics** | NOT sampled (always 100%) |
| **Exceptions** | Recommended: always capture (see adaptive sampling) |

### Azure App Setting Override

For runtime tuning without redeployment:

```bash
az webapp config appsettings set \
  --name mywebapp \
  --resource-group myrg \
  --settings OTEL_SAMPLING_RATIO=0.05  # Reduce to 5% during high load
```

> 📖 [OpenTelemetry configuration for Azure Monitor](https://learn.microsoft.com/azure/azure-monitor/app/opentelemetry-configuration?tabs=aspnetcore)  
> 📖 [Sampling in Application Insights](https://learn.microsoft.com/azure/azure-monitor/app/sampling-classic-api)

---

## 3. Logging Cost Controls

### The Cost of Logging

| Log Type | Typical Size | 1M Requests/day Cost Impact |
|----------|--------------|------------------------------|
| Structured log (1 line) | ~500 bytes | ~15 GB/month |
| Request body (JSON) | ~5 KB | ~150 GB/month |
| Full headers | ~2 KB | ~60 GB/month |
| Stack trace | ~3 KB | ~90 GB/month |

**Azure Monitor ingestion**: ~$2.76/GB (pay-as-you-go)  
**1M requests with bodies**: ~$400/month in logs alone

### DO ✅

| Practice | Example |
|----------|---------|
| Use structured logging | `_logger.LogInformation("Order processed: {OrderId}, {Amount}", orderId, amount);` |
| Log business events | Order created, payment failed, user login |
| Include correlation IDs | Automatic with OpenTelemetry |
| Filter noisy categories | See config below |
| Use appropriate log levels | `Debug` for dev, `Information`+ for prod |

### DON'T ❌

| Anti-Pattern | Why It's Bad | Alternative |
|--------------|--------------|-------------|
| Log request/response bodies | Huge volume, PII risk | Log summary: status, size, duration |
| Log all headers | Auth tokens, cookies exposed | Log specific safe headers if needed |
| Log inside tight loops | Millions of entries | Log aggregates or sample |
| Use string interpolation | `$"Order {id}"` loses structure | Use structured: `"{OrderId}", id` |
| Log sensitive data | PII, secrets, tokens | Redact or omit entirely |

### Example: What NOT to Log

```csharp
// ❌ BAD - Logs entire request body (expensive, PII risk)
_logger.LogInformation("Request: {Body}", await request.Content.ReadAsStringAsync());

// ❌ BAD - Logs all headers (secrets leak)
_logger.LogInformation("Headers: {Headers}", string.Join(", ", request.Headers));

// ❌ BAD - Logs in loop (volume explosion)
foreach (var item in thousandItems)
{
    _logger.LogDebug("Processing item {Id}", item.Id);
}

// ✅ GOOD - Log aggregate
_logger.LogInformation("Processing batch: {Count} items, {TotalValue:C}", 
    items.Count, items.Sum(i => i.Value));
```

### appsettings.json Log Level Filters

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft": "Warning",
      "Microsoft.AspNetCore": "Warning",
      "Microsoft.AspNetCore.Hosting.Diagnostics": "Warning",
      "Microsoft.AspNetCore.Routing": "Warning",
      "Microsoft.AspNetCore.Mvc": "Warning",
      "Microsoft.EntityFrameworkCore": "Warning",
      "Microsoft.EntityFrameworkCore.Database.Command": "Warning",
      "System": "Warning",
      "System.Net.Http.HttpClient": "Warning",
      "Azure": "Warning",
      "Azure.Core": "Warning",
      "Azure.Identity": "Warning"
    },
    "ApplicationInsights": {
      "LogLevel": {
        "Default": "Information",
        "Microsoft": "Warning"
      }
    }
  }
}
```

### Production-Specific Overrides

**appsettings.Production.json**:

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Warning",
      "Microsoft": "Error",
      "System": "Error",
      "YourApp.BusinessLogic": "Information"
    }
  }
}
```

### High-Traffic Services: Additional Controls

For services handling >10K requests/minute:

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Error",
      "YourApp": "Warning",
      "YourApp.Critical": "Information"
    }
  },
  "AzureMonitor": {
    "SamplingRatio": 0.01
  }
}
```

---

## 4. Quick Reference: Environment Defaults

| Setting | Development | Production |
|---------|-------------|------------|
| LAW Retention | 14 days | 30 days |
| Sampling Ratio | 1.0 (100%) | 0.1 (10%) |
| Default Log Level | Information | Warning |
| App Log Level | Debug | Information |
| Microsoft.* | Information | Warning/Error |

### Bicep Parameter Files

**parameters/dev.bicepparam**:

```bicep
using '../main.bicep'

param env = 'dev'
param logRetentionDays = 14
param tagPolicyEffect = 'Audit'
// ... other params
```

**parameters/prod.bicepparam**:

```bicep
using '../main.bicep'

param env = 'prod'
param logRetentionDays = 30
param tagPolicyEffect = 'Deny'
// ... other params
```

---

## 5. How to Tune Later: Per-Table Retention

### Concept

Log Analytics allows different retention periods per table. This is useful when:

- Security logs need 90+ days (compliance)
- Verbose diagnostic tables need only 7 days
- Metrics need longer retention than traces

### Tables in Workspace-Based Application Insights

| Table | Content | Suggested Retention |
|-------|---------|---------------------|
| `AppRequests` | Incoming requests | 30 days |
| `AppDependencies` | Outbound calls | 30 days |
| `AppExceptions` | Errors and stack traces | 90 days |
| `AppTraces` | Custom logs | 14-30 days |
| `AppMetrics` | Aggregated metrics | 90 days |
| `AppPageViews` | Browser telemetry | 30 days |
| `AppPerformanceCounters` | System counters | 14 days |

### Future Bicep: Per-Table Retention (Not Implemented Yet)

```bicep
// Example for future implementation
resource tableRetention 'Microsoft.OperationalInsights/workspaces/tables@2022-10-01' = {
  parent: logAnalyticsWorkspace
  name: 'AppExceptions'
  properties: {
    retentionInDays: 90  // Override workspace default
    totalRetentionInDays: 365  // Archive tier
  }
}
```

### Archive Tier (Long-Term Storage)

For compliance requiring 1+ year retention:

| Tier | Retention | Cost | Query |
|------|-----------|------|-------|
| Interactive | 30-730 days | $$$ | Instant |
| Archive | Up to 12 years | $ | Restore required |

> 📖 [Configure data retention and archive](https://learn.microsoft.com/azure/azure-monitor/logs/data-retention-archive)  
> 📖 [Table-level retention in Log Analytics](https://learn.microsoft.com/azure/azure-monitor/logs/data-retention-configure#configure-retention-and-archive-at-the-table-level)

---

## 6. Cost Monitoring

### KQL: Estimate Ingestion by Table

```kusto
// Run in Log Analytics to see data volume
Usage
| where TimeGenerated > ago(30d)
| summarize 
    TotalGB = sum(Quantity) / 1024,
    AvgDailyGB = sum(Quantity) / 1024 / 30
    by DataType
| order by TotalGB desc
```

### KQL: Identify Noisy Sources

```kusto
// Find log sources generating the most data
AppTraces
| where TimeGenerated > ago(7d)
| summarize 
    Count = count(),
    EstimatedGB = sum(estimate_data_size(*)) / 1024 / 1024 / 1024
    by AppRoleName, SeverityLevel
| order by EstimatedGB desc
| take 20
```

### Azure Cost Management Alerts

Set up budget alerts when Log Analytics costs exceed thresholds:

```bicep
// Future: Add Azure Budget resource for monitoring costs
```

---

## 7. Checklist: New Service Onboarding

When adding a new service to the Monitoring Golden Path:

- [ ] Connection string configured (`APPLICATIONINSIGHTS_CONNECTION_STRING`)
- [ ] Sampling ratio set appropriately for environment
- [ ] Log levels configured (noisy categories filtered)
- [ ] No request/response body logging
- [ ] No sensitive header logging
- [ ] Structured logging used (`{PropertyName}` syntax)
- [ ] Service.name and deployment.environment attributes set
- [ ] Verified in Application Map (traces connect)

---

## References

### Retention & Archive
- [Data retention and archive in Azure Monitor Logs](https://learn.microsoft.com/azure/azure-monitor/logs/data-retention-archive)
- [Configure retention at table level](https://learn.microsoft.com/azure/azure-monitor/logs/data-retention-configure)
- [Log Analytics pricing](https://azure.microsoft.com/pricing/details/monitor/)

### Sampling
- [Sampling in Application Insights](https://learn.microsoft.com/azure/azure-monitor/app/sampling-classic-api)
- [OpenTelemetry configuration for Azure Monitor](https://learn.microsoft.com/azure/azure-monitor/app/opentelemetry-configuration?tabs=aspnetcore)

### Logging Best Practices
- [Logging in .NET](https://learn.microsoft.com/dotnet/core/extensions/logging)
- [High-performance logging in .NET](https://learn.microsoft.com/dotnet/core/extensions/high-performance-logging)
