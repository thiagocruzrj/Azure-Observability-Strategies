Topic: Security / governance for observability (minimum viable, but real)

Goal
Define baseline security and governance for the Monitoring Golden Path:
- Clear RBAC separation for monitoring access
- Explicit PII policy for telemetry (default deny)

Context
- A dedicated monitoring Resource Group exists.
- Log Analytics Workspace (LAW) exists.
- Workspace-based Application Insights exists (web/api/func).
- Apps use APPLICATIONINSIGHTS_CONNECTION_STRING.
- Alerts, dashboards, and workbooks already exist.

Non-negotiables (RBAC)
1) Define TWO access levels for observability:
   A) Read-only monitoring users
   B) Monitoring contributors (can configure alerts, workbooks, diagnostic settings)

2) Use Azure built-in roles where possible:
   - Read-only monitoring:
     * Log Analytics Reader
     * Application Insights Reader
   - Monitoring contributors:
     * Log Analytics Contributor
     * Application Insights Contributor

3) Scope:
   - Assign roles at the monitoring Resource Group level (preferred).
   - Do NOT assign at subscription scope in this iteration.
   - Avoid overly broad roles (no Owner / Contributor).

4) Bicep requirements:
   - Accept parameters:
     * monitoringReadersPrincipalIds (array of objectIds)
     * monitoringContributorsPrincipalIds (array of objectIds)
   - Create Microsoft.Authorization/roleAssignments for each role and principal.
   - Use deterministic GUIDs for roleAssignments (no random names).

Non-negotiables (PII governance for telemetry)
5) Define a PII rule:
   - Default: NO PII in telemetry.
   - Telemetry must never contain:
     * names, emails, phone numbers
     * national IDs
     * authentication tokens, cookies, authorization headers
     * request/response bodies by default

6) Allowed by default:
   - operation names
   - route templates (NOT raw URLs with identifiers)
   - status codes
   - duration / latency
   - dependency type + target (no payloads)
   - synthetic identifiers (correlation IDs, trace IDs)

7) Scrubbing / enforcement guidance (documentation, not enforcement in Bicep):
   - ASP.NET Core:
     * use structured logging
     * avoid logging HttpRequest/HttpResponse bodies
     * filter headers explicitly (e.g., Authorization, Cookie)
     * use telemetry processors / enrichers when needed
   - Azure Functions:
     * same rules apply
     * never log input/output bindings with sensitive data

Deliverable
- Generate:
  1) Bicep module:
     - modules/security-observability.bicep
     - RBAC role assignments only
  2) A markdown-style governance section (as comments or separate snippet) titled:
     "Telemetry PII Policy"
     explaining:
       - what is forbidden
       - what is allowed
       - how developers should scrub data
       - how to request exceptions (manual process)

Important
- This is minimum viable governance, not full compliance automation.
- Do NOT invent Azure Policy or DLP enforcement here.
- Keep it realistic and aligned with Azure Monitor best practices.
