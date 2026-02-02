# Distributed Tracing Demo

This demo proves end-to-end distributed tracing across three .NET services using Azure Monitor OpenTelemetry, following our PII governance policy (no sensitive data in telemetry).

## Architecture

```
┌─────────────┐     HTTP      ┌─────────────┐     HTTP      ┌─────────────┐
│  Demo.Web   │ ───────────▶  │  Demo.Api   │ ───────────▶  │  Demo.Func  │
│ (ASP.NET)   │               │ (ASP.NET)   │               │ (Functions) │
└─────────────┘               └─────────────┘               └─────────────┘
     │                              │                              │
     └──────────────────────────────┴──────────────────────────────┘
                                    │
                                    ▼
                        ┌───────────────────────┐
                        │  Application Insights │
                        │  (Log Analytics)      │
                        └───────────────────────┘
```

## Flow

1. **GET /demo** on Demo.Web
   - Generates a synthetic `orderId` (GUID)
   - Calls Demo.Api `/orders/{orderId}`
   - Returns combined response

2. **GET /orders/{orderId}** on Demo.Api
   - Receives the order request
   - Calls Demo.Func `/api/enrich?orderId=...`
   - Returns enriched order data

3. **GET /api/enrich** on Demo.Func
   - Enriches the order with metadata
   - Optionally reads from Azure Blob Storage (if `ENABLE_STORAGE_DEPENDENCY=true`)
   - Returns enrichment data

## Prerequisites

- .NET 9 SDK (or .NET 8 SDK for Functions)
- Azure Functions Core Tools v4
- Application Insights resource (connection string)

## Quick Start

### 1. Set Connection String

Set the Application Insights connection string as an environment variable:

```bash
# PowerShell
$env:APPLICATIONINSIGHTS_CONNECTION_STRING = "InstrumentationKey=...;IngestionEndpoint=..."

# Bash
export APPLICATIONINSIGHTS_CONNECTION_STRING="InstrumentationKey=...;IngestionEndpoint=..."
```

Or update each service's `appsettings.Development.json`.

### 2. Start Services (3 terminals)

**Terminal 1 - Functions (port 7073):**
```bash
cd demo/Demo.Func
func start --port 7073
```

**Terminal 2 - API (port 5002):**
```bash
cd demo/Demo.Api
dotnet run --urls "http://localhost:5002"
```

**Terminal 3 - Web (port 5001):**
```bash
cd demo/Demo.Web
dotnet run --urls "http://localhost:5001"
```

### 3. Trigger the Demo

```bash
curl http://localhost:5001/demo
```

Expected response:
```json
{
  "traceId": "abc123...",
  "orderId": "550e8400-e29b-41d4-a716-446655440000",
  "web": {
    "service": "Demo.Web",
    "timestamp": "2026-02-02T10:30:00Z"
  },
  "api": {
    "service": "Demo.Api",
    "orderId": "550e8400-e29b-41d4-a716-446655440000",
    "status": "processed"
  },
  "enrichment": {
    "service": "Demo.Func",
    "orderId": "550e8400-e29b-41d4-a716-446655440000",
    "priority": "standard",
    "region": "us-east",
    "storageChecked": false
  }
}
```

### 4. Verify in Application Insights

1. Open Azure Portal → Application Insights
2. Go to **Transaction search** or **Application Map**
3. Find operations with the trace ID from the response
4. Verify the full trace spans all three services

## Governance Compliance

This demo follows the Telemetry PII Policy:

✅ **What IS logged:**
- Trace IDs (W3C format)
- Synthetic order IDs (GUIDs)
- Operation names
- Status codes
- Durations
- Service names

❌ **What is NOT logged:**
- Request/response bodies
- Authorization headers
- Cookies
- Real customer data
- IP addresses

## Configuration

### Sampling Ratio

Adjust sampling per environment:

| Environment | Sampling Ratio | Config Key |
|-------------|----------------|------------|
| Development | 1.0 (100%) | `AzureMonitor:SamplingRatio` |
| Production | 0.1 (10%) | `AzureMonitor:SamplingRatio` |

### Storage Dependency (Optional)

To enable the optional Blob Storage dependency in Demo.Func:

```json
{
  "ENABLE_STORAGE_DEPENDENCY": "true",
  "STORAGE_CONNECTION_STRING": "DefaultEndpointsProtocol=..."
}
```

## Project Structure

```
demo/
├── Demo.Web/           # Frontend web service
│   ├── Program.cs
│   ├── Demo.Web.csproj
│   └── appsettings.Development.json
├── Demo.Api/           # Backend API service
│   ├── Program.cs
│   ├── Demo.Api.csproj
│   └── appsettings.Development.json
├── Demo.Func/          # Azure Functions service
│   ├── Program.cs
│   ├── EnrichFunction.cs
│   ├── Demo.Func.csproj
│   ├── host.json
│   └── local.settings.json
└── README.md           # This file
```
