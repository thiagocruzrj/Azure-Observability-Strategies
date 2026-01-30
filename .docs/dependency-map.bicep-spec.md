Topic: Distributed tracing & correlation (“dependency map”)

I need a production-ready, consistent OpenTelemetry standard for:
1) ASP.NET Core Web/API apps
2) Azure Functions (.NET)

Non-negotiables (Web/API)
- Use Azure Monitor OpenTelemetry Distro for ASP.NET Core:
  package: Azure.Monitor.OpenTelemetry.AspNetCore
- Use ONLY APPLICATIONINSIGHTS_CONNECTION_STRING (no instrumentation keys).
- The distro provides ASP.NET Core + HttpClient instrumentation by default.
- Must support sampling ratio configuration (0..1) and allow per-env tuning.

Deliverable (Web/API)
- Provide a minimal code snippet for Program.cs showing:
  - AddAzureMonitorOpenTelemetry()
  - reading APPLICATIONINSIGHTS_CONNECTION_STRING from env/appsettings
  - sampling ratio configured from config (e.g., OTEL_SAMPLING_RATIO)
  - adding basic resource attributes (service.name, service.version, deployment.environment)
- Provide recommended conventions:
  - consistent service.name (web/api) and env tag
  - W3C tracecontext propagation (default)
  - correlation across HttpClient dependencies

Non-negotiables (Azure Functions)
- For end-to-end OTel semantics, enable OpenTelemetry at the Functions host level using:
  host.json: "telemetryMode": "OpenTelemetry"
- OpenTelemetry isn't supported for C# in-process Functions; use .NET isolated.
- Warn explicitly about duplicate telemetry when combining:
  - host telemetry (Functions host) + worker instrumentation (isolated worker)
  and provide guidance to avoid duplicates (choose one approach, or configure accordingly).

Deliverable (Functions)
- Provide a host.json snippet showing telemetryMode OpenTelemetry.
- Provide a short note stating: use .NET isolated worker, not in-process.
- Provide a minimal isolated worker Program.cs snippet that uses the Functions worker OpenTelemetry package (if appropriate) and aligns with Azure Monitor export.
- Include a “gotchas” section: duplicate telemetry and how to detect it.

Output format
- Write it as a short internal engineering standard (markdown):
  - Goal
  - Web/API standard
  - Functions standard
  - Sampling standard
  - Pitfalls & troubleshooting
- Include links to the official Microsoft docs as inline references (not raw URLs).
