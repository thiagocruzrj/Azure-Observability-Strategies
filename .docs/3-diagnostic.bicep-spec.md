# Step C — Standardize Diagnostic Settings (Platform Logs → LAW)

## ✅ Status: COMPLETED

Diagnostic settings module: `modules/diagnosticSettings-websites.bicep`

---

## 1. Web App Diagnostic Settings → Send Platform Logs to LAW

### Configuration

| Property | Value |
|----------|-------|
| **Destination** | Log Analytics Workspace: `law-obs-demo-dev-weu` |
| **Setting Name** | `diag-web-obs-demo-dev-weu` |

### Log Categories (Intentional Selection)

| Category | Enabled | Description |
|----------|---------|-------------|
| `AppServiceHTTPLogs` | ✅ | HTTP request/response logs |
| `AppServiceConsoleLogs` | ✅ | Console output from app |
| `AppServiceAppLogs` | ✅ | Application logs |
| `AppServiceAuditLogs` | ✅ | Audit events |
| `AppServicePlatformLogs` | ✅ | Platform-level logs |
| `AppServiceIPSecAuditLogs` | ❌ | Optional - IP security audit |

> ⚠️ **Warning**: Expect app restart when enabling diagnostic settings.

---

## 2. API App Diagnostic Settings → Send Platform Logs to LAW

Repeat the same configuration as Web App:

| Property | Value |
|----------|-------|
| **Destination** | Log Analytics Workspace: `law-obs-demo-dev-weu` |
| **Setting Name** | `diag-api-obs-demo-dev-weu` |
| **Categories** | Same as Web App |

> ⚠️ **Warning**: Expect app restart here too.

---

## 3. Function App Monitoring Setup

### Application Insights Connection

| Property | Value |
|----------|-------|
| **Connection** | Via `APPLICATIONINSIGHTS_CONNECTION_STRING` app setting |
| **Target** | `appi-func-demo-dev-weu` |

### OpenTelemetry Configuration

Update `host.json` for full OTel semantics:

```json
{
  "version": "2.0",
  "logging": {
    "applicationInsights": {
      "samplingSettings": {
        "isEnabled": true,
        "excludedTypes": "Request"
      }
    }
  },
  "telemetryMode": "OpenTelemetry"
}
```

> ✅ **Important**: Use **.NET Isolated** worker model. In-process OTel is NOT supported.

---

## Bicep Module Usage

```bicep
// Deploy diagnostic settings for App Services
module webDiagnostics 'modules/diagnosticSettings-websites.bicep' = {
  name: 'diag-web-${env}'
  scope: resourceGroup(resourceGroupName)
  params: {
    appServiceName: 'web-obs-demo-dev-weu'
    diagnosticSettingName: 'diag-web-obs-demo-dev-weu'
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    enableIPSecAuditLogs: false
  }
}
```

---

## Verify Logs Are Flowing

```kusto
// Check App Service logs in LAW
AppServiceHTTPLogs
| where TimeGenerated > ago(1h)
| project TimeGenerated, CsHost, CsUriStem, ScStatus, TimeTaken
| order by TimeGenerated desc
| take 20
```
