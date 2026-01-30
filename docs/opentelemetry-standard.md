# OpenTelemetry Standard for Distributed Tracing

> **Internal Engineering Standard** | Version 1.0 | January 2026

## Goal

Establish a consistent, production-ready OpenTelemetry implementation across all .NET workloads to enable:

- **End-to-end distributed tracing** with automatic correlation across services
- **Dependency mapping** in Application Insights (Application Map)
- **W3C TraceContext propagation** (industry standard)
- **Environment-specific sampling** to control costs while maintaining observability

This standard applies to:
- ASP.NET Core Web/API applications
- Azure Functions (.NET isolated worker)

---

## Web/API Standard (ASP.NET Core)

### Package Reference

```xml
<PackageReference Include="Azure.Monitor.OpenTelemetry.AspNetCore" Version="1.3.0" />
```

> 📖 [Azure Monitor OpenTelemetry Distro for .NET](https://learn.microsoft.com/azure/azure-monitor/app/opentelemetry-enable?tabs=aspnetcore)

### Configuration (appsettings.json)

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

Environment-specific overrides (`appsettings.Production.json`):

```json
{
  "AzureMonitor": {
    "SamplingRatio": 0.1
  }
}
```

### Program.cs Implementation

```csharp
using Azure.Monitor.OpenTelemetry.AspNetCore;
using OpenTelemetry.Resources;

var builder = WebApplication.CreateBuilder(args);

// ============================================================================
// OpenTelemetry Configuration - Azure Monitor Distro
// ============================================================================

// Read configuration
var serviceName = builder.Configuration["ServiceInfo:Name"] ?? "unknown-service";
var serviceVersion = builder.Configuration["ServiceInfo:Version"] ?? "0.0.0";
var environment = builder.Environment.EnvironmentName.ToLowerInvariant();

// Sampling ratio: 1.0 = 100%, 0.1 = 10%, 0.0 = 0%
// Override via environment variable: OTEL_SAMPLING_RATIO
var samplingRatio = float.TryParse(
    Environment.GetEnvironmentVariable("OTEL_SAMPLING_RATIO"),
    out var envSampling)
    ? envSampling
    : builder.Configuration.GetValue<float>("AzureMonitor:SamplingRatio", 1.0f);

// Add Azure Monitor OpenTelemetry
// Connection string read from: APPLICATIONINSIGHTS_CONNECTION_STRING (env var or config)
builder.Services.AddOpenTelemetry()
    .ConfigureResource(resource => resource
        .AddService(
            serviceName: serviceName,
            serviceVersion: serviceVersion)
        .AddAttributes(new Dictionary<string, object>
        {
            ["deployment.environment"] = environment,
            ["service.namespace"] = "demoapp",  // Group related services
            ["service.instance.id"] = Environment.MachineName
        }))
    .UseAzureMonitor(options =>
    {
        // Connection string from environment variable (preferred) or config
        // DO NOT use instrumentation keys - they are deprecated
        options.ConnectionString = Environment.GetEnvironmentVariable("APPLICATIONINSIGHTS_CONNECTION_STRING")
            ?? builder.Configuration["ApplicationInsights:ConnectionString"];
        
        // Configure sampling
        options.SamplingRatio = samplingRatio;
    });

// ============================================================================
// Application Services
// ============================================================================

builder.Services.AddControllers();
builder.Services.AddHttpClient(); // Automatically instrumented by distro

var app = builder.Build();

app.MapControllers();
app.Run();
```

### What the Distro Provides Automatically

| Instrumentation | Included | Notes |
|-----------------|----------|-------|
| ASP.NET Core requests | ✅ | Incoming HTTP requests |
| HttpClient calls | ✅ | Outgoing HTTP dependencies |
| SQL Client | ✅ | Database calls |
| Azure SDK calls | ✅ | Storage, Service Bus, etc. |
| W3C TraceContext | ✅ | Propagation enabled by default |
| Live Metrics | ✅ | Real-time telemetry stream |

### Service Naming Convention

| Component | `service.name` | Example |
|-----------|----------------|---------|
| Web frontend | `web-{workload}` | `web-demoapp` |
| API backend | `api-{workload}` | `api-demoapp` |
| Background worker | `worker-{workload}` | `worker-demoapp` |

---

## Functions Standard (.NET Isolated Worker)

### ⚠️ Critical Requirements

1. **Use .NET Isolated Worker model only** - OpenTelemetry is NOT supported for C# in-process Functions
2. **Enable OpenTelemetry at the Functions host level** via `host.json`
3. **Beware of duplicate telemetry** when combining host + worker instrumentation

> 📖 [Azure Functions OpenTelemetry](https://learn.microsoft.com/azure/azure-functions/opentelemetry-howto?tabs=isolated-process)

### host.json Configuration

```json
{
  "version": "2.0",
  "telemetryMode": "OpenTelemetry",
  "logging": {
    "applicationInsights": {
      "samplingSettings": {
        "isEnabled": true,
        "maxTelemetryItemsPerSecond": 20,
        "excludedTypes": "Request;Dependency"
      }
    },
    "logLevel": {
      "default": "Information",
      "Host.Results": "Error",
      "Function": "Information",
      "Host.Aggregator": "Trace"
    }
  }
}
```

### Package References (Isolated Worker)

```xml
<PackageReference Include="Microsoft.Azure.Functions.Worker" Version="2.0.0" />
<PackageReference Include="Microsoft.Azure.Functions.Worker.Sdk" Version="2.0.0" />
<PackageReference Include="Microsoft.Azure.Functions.Worker.ApplicationInsights" Version="2.0.0" />
```

### Program.cs Implementation (Isolated Worker)

```csharp
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

var host = new HostBuilder()
    .ConfigureFunctionsWorkerDefaults(worker =>
    {
        // Enable Application Insights integration for isolated worker
        // This connects worker telemetry to the host's OpenTelemetry pipeline
        worker.AddApplicationInsights()
              .AddApplicationInsightsLogger();
    })
    .ConfigureServices(services =>
    {
        // Add HttpClient with automatic correlation
        services.AddHttpClient();
    })
    .Build();

host.Run();
```

### App Settings (Required)

```json
{
  "APPLICATIONINSIGHTS_CONNECTION_STRING": "<your-connection-string>",
  "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated"
}
```

### Duplicate Telemetry: Detection & Prevention

#### ⚠️ The Problem

When both the Functions host AND the isolated worker send telemetry, you may see:

- **Duplicate requests** - Same HTTP trigger logged twice
- **Duplicate dependencies** - Same outbound call logged twice
- **Inflated metrics** - Request counts, failure rates doubled
- **Increased costs** - Paying for redundant data ingestion

#### How to Detect Duplicates

Run this KQL query in Log Analytics:

```kusto
// Detect potential duplicate telemetry
requests
| where timestamp > ago(1h)
| where cloud_RoleName contains "func"
| summarize 
    Count = count(),
    DistinctOperations = dcount(operation_Id)
    by cloud_RoleName, name, bin(timestamp, 1m)
| where Count > DistinctOperations * 1.5  // Flag if count >> distinct operations
| order by timestamp desc
```

#### Prevention Strategy

**Option A: Host-only telemetry (Recommended for most cases)**

Let the Functions host handle all telemetry via `telemetryMode: "OpenTelemetry"`. 
Do NOT add Application Insights packages to the worker.

```csharp
// Program.cs - Minimal, no AI packages
var host = new HostBuilder()
    .ConfigureFunctionsWorkerDefaults()
    .Build();

host.Run();
```

**Option B: Worker telemetry with host sampling disabled**

If you need fine-grained control in the worker:

```json
// host.json - Disable host-level AI sampling for types you handle in worker
{
  "version": "2.0",
  "telemetryMode": "OpenTelemetry",
  "logging": {
    "applicationInsights": {
      "samplingSettings": {
        "isEnabled": true,
        "excludedTypes": "Request;Dependency;Trace"
      }
    }
  }
}
```

**Option C: Isolated worker with full OpenTelemetry SDK (Advanced)**

For complete control, use the OpenTelemetry SDK directly in the worker:

```csharp
// Only if you need custom instrumentation beyond what the host provides
// Requires careful configuration to avoid duplicates
.ConfigureServices(services =>
{
    services.AddOpenTelemetry()
        .ConfigureResource(r => r.AddService("func-demoapp"))
        .WithTracing(tracing => tracing
            .AddSource("MyCustomSource")  // Only custom sources, not HTTP
            .AddAzureMonitorTraceExporter());
})
```

---

## Sampling Standard

### Recommended Sampling Ratios by Environment

| Environment | Sampling Ratio | Rationale |
|-------------|----------------|-----------|
| Development | `1.0` (100%) | Full visibility for debugging |
| Staging | `0.5` (50%) | Balance between visibility and realism |
| Production | `0.1` (10%) | Cost control with statistical significance |
| Production (high-traffic) | `0.01` (1%) | High-volume services (>10K req/min) |

### Configuration Priority

1. **Environment variable** `OTEL_SAMPLING_RATIO` (highest priority)
2. **App setting** in Azure portal
3. **appsettings.{Environment}.json**
4. **appsettings.json** (default)

### Adaptive Sampling Note

Azure Monitor distro includes adaptive sampling that automatically adjusts based on telemetry volume. The `SamplingRatio` sets the **target** ratio, but actual sampling may vary.

---

## Pitfalls & Troubleshooting

### Common Issues

| Issue | Symptom | Solution |
|-------|---------|----------|
| Missing correlation | Traces don't connect across services | Ensure `traceparent` header propagates; check HttpClient is from DI |
| No telemetry | Zero data in Application Insights | Verify `APPLICATIONINSIGHTS_CONNECTION_STRING` is set correctly |
| Duplicate data | Same events appear twice | See Functions duplicate telemetry section above |
| High costs | Unexpected Azure Monitor bills | Reduce sampling ratio; check for logging loops |
| Missing dependencies | Outbound calls not tracked | Ensure HttpClient from DI, not `new HttpClient()` |

### Diagnostic Checklist

```bash
# 1. Verify connection string is set
echo $APPLICATIONINSIGHTS_CONNECTION_STRING

# 2. Check for W3C headers in outbound requests
curl -v https://your-api.com/endpoint 2>&1 | grep -i traceparent

# 3. Verify telemetry in Application Insights (KQL)
# Run in Log Analytics:
traces | where timestamp > ago(5m) | take 10
```

### KQL: Validate Distributed Tracing

```kusto
// Find all operations spanning multiple services
requests
| where timestamp > ago(1h)
| join kind=inner (
    dependencies
    | where timestamp > ago(1h)
) on operation_Id
| summarize 
    Services = make_set(cloud_RoleName),
    ServiceCount = dcount(cloud_RoleName)
    by operation_Id
| where ServiceCount > 1
| order by ServiceCount desc
| take 100
```

### KQL: Identify Sampling Rate

```kusto
// Check effective sampling rate
requests
| where timestamp > ago(1h)
| summarize 
    TotalCount = count(),
    SampledCount = countif(itemCount == 1)
| extend EffectiveSamplingRate = round(100.0 * SampledCount / TotalCount, 2)
```

---

## Quick Reference

### App Settings (Azure Portal / Bicep)

| Setting | Required | Example |
|---------|----------|---------|
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | ✅ | `InstrumentationKey=...;IngestionEndpoint=...` |
| `OTEL_SAMPLING_RATIO` | Optional | `0.1` |
| `ASPNETCORE_ENVIRONMENT` | Recommended | `Production` |

### DO ✅

- Use connection strings (not instrumentation keys)
- Inject `HttpClient` via dependency injection
- Set meaningful `service.name` for each component
- Configure sampling per environment
- Use isolated worker for Functions with OpenTelemetry

### DON'T ❌

- Use instrumentation keys (deprecated)
- Create `new HttpClient()` directly (breaks correlation)
- Enable both host + worker telemetry without exclusions
- Use in-process Functions with OpenTelemetry
- Set sampling to 0 in production (lose all observability)

---

## References

- [Azure Monitor OpenTelemetry Distro for .NET](https://learn.microsoft.com/azure/azure-monitor/app/opentelemetry-enable?tabs=aspnetcore)
- [OpenTelemetry .NET SDK](https://opentelemetry.io/docs/languages/net/)
- [Azure Functions OpenTelemetry](https://learn.microsoft.com/azure/azure-functions/opentelemetry-howto?tabs=isolated-process)
- [W3C Trace Context](https://www.w3.org/TR/trace-context/)
- [Application Insights Sampling](https://learn.microsoft.com/azure/azure-monitor/app/sampling)
- [Distributed Tracing in Azure](https://learn.microsoft.com/azure/azure-monitor/app/distributed-trace-data)
