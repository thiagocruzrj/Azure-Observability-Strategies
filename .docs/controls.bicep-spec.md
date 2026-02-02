Topic: Sampling / retention / cost controls (sustainable observability)

Context
- We already have:
  - One Log Analytics Workspace (LAW) per environment (dev/prod)
  - Workspace-based Application Insights per component (web/api/func)
  - Apps use APPLICATIONINSIGHTS_CONNECTION_STRING everywhere (no instrumentation keys)
  - Diagnostic settings exist for App Services (web/api) sending selected platform logs to LAW

Non-negotiables (LAW retention)
1) Set default retention on the LAW via Bicep:
   - devRetentionDays: 14 (shorter)
   - prodRetentionDays: 30 (longer)  [parameterize; values must be configurable]
2) Note that the workspace retention is a default; we will tune per-table retention later (do NOT implement per-table retention in this iteration unless asked).

Non-negotiables (sampling)
3) For ASP.NET Core Web/API using Azure Monitor OpenTelemetry Distro:
   - package: Azure.Monitor.OpenTelemetry.AspNetCore
   - Configure fixed-rate sampling ratio (0..1) via configuration:
     - devSamplingRatio: 1.0
     - prodSamplingRatio: 0.1
   - Must preserve end-to-end traces (avoid broken traces) and keep correlation (W3C tracecontext default).
   - Use APPLICATIONINSIGHTS_CONNECTION_STRING only.

Non-negotiables (logging cost controls)
4) “Do not log everything”:
   - Use structured logs (ILogger with structured properties).
   - Add explicit guidance to avoid logging request/response bodies and sensitive headers.
   - Filter noisy categories early using config-based log level overrides (e.g., Microsoft.*, System.Net.Http.*, Azure.*).
   - Emphasize cost: high-volume logs (bodies/headers) explode ingestion and reduce signal.

Deliverable
- Produce a short internal standard (markdown) with:
  - LAW retention defaults (dev vs prod) + why
  - Sampling standard (dev vs prod) + exact config snippet for ASP.NET Core Program.cs
  - Logging do’s/don’ts + example appsettings.json logging filters
  - “How to tune later” section (per-table retention strategy)
- Include references to official Microsoft docs for:
  - Log Analytics retention and per-table retention concepts
  - OpenTelemetry sampling with Azure Monitor

