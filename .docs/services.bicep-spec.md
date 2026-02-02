Create a 3-service .NET demo proving distributed tracing + governance (no PII).

Architecture:
Demo.Web (ASP.NET Core) -> calls -> Demo.Api (ASP.NET Core) -> calls -> Demo.Func (Azure Functions .NET isolated)

Requirements:
1) Web and API must use Azure Monitor OpenTelemetry Distro:
   - package Azure.Monitor.OpenTelemetry.AspNetCore
   - read APPLICATIONINSIGHTS_CONNECTION_STRING from env/config
   - configure SamplingRatio from config (0..1)
   - use HttpClientFactory for outbound HTTP calls
2) Correlation must work end-to-end with standard HttpClient.
3) Functions must be .NET isolated. Enable OTel semantics at the host level:
   - host.json: "telemetryMode": "OpenTelemetry"
   - avoid duplicate telemetry (do NOT add extra worker OTel instrumentation unless required)
4) Governance:
   - no logging of request/response bodies or sensitive headers (Authorization, Cookie)
   - structured logging only
   - log safe fields: traceId, synthetic orderId (GUID), status, duration
5) Provide endpoints:
   - Web: GET /demo triggers the chain
   - API: GET /orders/{orderId} calls Function and returns combined response
   - Function: GET /api/enrich?orderId=... returns enrichment info
6) Optional dependency node:
   - Function optionally calls Azure Blob Storage (read a known blob) controlled by a config flag ENABLE_STORAGE_DEPENDENCY.
7) Provide local run instructions + sample appsettings.Development.json for each service (without secrets).
