Topic: Operational layer (alerts + dashboards)

Goal
Provision the operational layer for our Monitoring Golden Path using Azure Bicep:
- One shared Action Group
- Baseline alert rules (App Service + Functions + App Insights)
- One Ops Workbook (overview + failures + dependency chain + recent alerts)
- Pin workbook to an Azure Portal dashboard

Context
- A dedicated monitoring resource group already exists.
- A Log Analytics Workspace exists.
- Workspace-based Application Insights exists per component: web, api, func.
- App Service diagnostics already send selected platform logs to LAW.

Non-negotiables (Action Group)
1) Create ONE Action Group in the monitoring RG and reuse it across ALL alerts.
2) Receivers:
   - Email receiver(s) (param: emailAddresses array)
   - Teams receiver via webhook OR Logic App receiver (param: teamsWebhookUrl string)
3) Enable common alert schema where applicable.
4) Output the actionGroupResourceId.

Non-negotiables (Baseline alerts)
Create these baseline alerts with sane defaults and environment tuning (dev vs prod):
A) App Service (Web/API)
- 5xx spike: metric alert
- latency: metric alert if possible, otherwise log alert (KQL) from AppInsights
- CPU high (App Service Plan): metric alert
- Memory high (App Service Plan): metric alert

B) Application Insights (Web/API/Func)
- exceptions: log alert (scheduledQueryRules) using App Insights / Logs (KQL)
- dependency failures / high dependency duration: log alert (KQL), optional flag

C) Azure Functions (Func)
- function failures: log alert (KQL) using App Insights logs (exceptions/failed requests) OR Functions logs in LAW if available

D) Availability (optional)
- If enableAvailabilityTest=true, create an availability test + alert on failures.

Rules
- All alerts must reference the shared Action Group.
- Alert severities (param per environment): prod more strict than dev.
- Add throttling / evaluation frequency sensible defaults.
- Include clear naming convention:
  - ag-mon-${env}-${workload}
  - alrt-${env}-${workload}-${component}-${signal}-${condition}

Non-negotiables (Workbook + Dashboard)
1) Create ONE shared Azure Monitor workbook:
   - sections: Overview, Failures, Dependency chain, Recent alerts
2) The workbook must query:
   - App Insights logs (requests, dependencies, exceptions)
   - Recent fired alerts (if possible via Azure Resource Graph / alerts tables)
3) Create a Portal dashboard and pin the workbook to it (if supported via ARM/Bicep). If dashboard pinning is not reliably supported, output the workbook URL and provide manual pin steps.

Deliverable
Generate a module (Bicep) plus a small README-style markdown inside comments:
- modules/ops-alerting-workbooks.bicep
- outputs: actionGroupId, alertRuleIds (array), workbookId, (optional) dashboardId
Also generate a minimal params example for env=dev.

Important
- Use correct Azure resource types:
  - Microsoft.Insights/actionGroups
  - Microsoft.Insights/metricAlerts
  - Microsoft.Insights/scheduledQueryRules (log alerts)
  - Microsoft.Insights/workbooks
  - (optional) Microsoft.Portal/dashboards
- Do not use instrumentation keys; only connection strings exist in apps (FYI).
