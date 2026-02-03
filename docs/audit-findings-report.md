# Azure Monitoring Audit - Findings Report

**Audit Date:** February 3, 2026  
**Client Environment:** 9 Target Subscriptions (scoped audit)

### Target Subscriptions

| Subscription Name | Subscription ID |
|-------------------|-----------------|
| Edv2 BR QA | `76cd0ab7-9ab0-412a-b927-cc10e3d656d3` |
| EVASM NEU PRO | `039c62ed-7e0c-4d56-bb3f-be23033758ce` |
| EVASM NEU QA | `98d67ae7-6840-4bbb-a9db-23f12702daec` |
| EVASM WUS PRO (LATAM) | `8300de04-726b-4119-8637-1920254b613b` |
| MAE LATAM PRO | `4f9b5670-6e01-452b-9068-534c3e8b80fd` |
| MAE NEU PRO | `04669dbd-24c3-4cbe-a6a0-dbae82a9cb91` |
| MAE NEU QA | `658a3795-22d3-4ac1-a87c-70810b337754` |
| RecursosInternos-DevOps | `2e3c305c-04a8-48f7-b8f7-e615c5bf8669` |
| RecursosInternos-DevOps QA | `1d08dafe-eb6c-4aa7-b738-a851f0959ba7` |

---

## Executive Summary

| Category | Finding | Severity |
|----------|---------|----------|
| Application Insights | 72 App Services without monitoring | 🔴 Critical |
| Application Insights | 0 App Insights instances in audit scope | 🔴 Critical |
| Tag Compliance | 994 resources missing required tags | 🟠 High |
| Alert Coverage | Missing availability & health check alerts | 🟠 High |
| Alert Coverage | No Function App specific alerts | 🟠 High |
| Alert Rules | 22 alert rules disabled | 🟡 Medium |
| Alert Coverage | Missing App Insights-based alerts | 🟡 Medium |

---

## 1. Resource Inventory

### 1.1 App Services Breakdown (by Subscription)

| Subscription | Web Apps | Function Apps | API Apps | Total |
|--------------|----------|---------------|----------|-------|
| EVASM NEU PRO | 10 | 3 | - | 13 |
| EVASM NEU QA | 12 | 4 | - | 16 |
| EVASM WUS PRO (LATAM) | 8 | 0 | - | 8 |
| MAE NEU PRO | 9 | 1 | - | 10 |
| MAE NEU QA | 9 | 2 | - | 11 |
| MAE LATAM PRO | 6 | 1 | - | 7 |
| Edv2 BR QA | 2 | 1 | - | 3 |
| RecursosInternos-DevOps | 0 | 3 | - | 3 |
| RecursosInternos-DevOps QA | 0 | 1 | - | 1 |
| **Total** | **56** | **16** | **15*** | **72** |

> *Note: API Apps counted within Web Apps in az webapp list; total of 72 from Resource Graph query

### 1.2 Monitoring Resources (Audit Scope)

| Resource Type | Count | Notes |
|---------------|-------|-------|
| Application Insights | 0 | ⚠️ None in audited subscriptions! |
| Log Analytics Workspaces | 26 | Across 9 subscriptions |
| Metric Alerts | 211 | Active + Disabled |
| Scheduled Query Alerts | 5 | Backup failure alerts |
| Action Groups | 10 | |
| **Total Resources** | **994** | |

### 1.3 Alert Distribution by Subscription

| Subscription | Metric Alerts | Query Alerts | Action Groups |
|--------------|---------------|--------------|---------------|
| EVASM NEU PRO | 52 | 1 | 0 |
| MAE NEU PRO | 57 | 1 | 1 |
| EVASM WUS PRO (LATAM) | 47 | 1 | 1 |
| MAE LATAM PRO | 47 | 1 | 1 |
| EVASM NEU QA | 3 | 0 | 0 |
| MAE NEU QA | 1 | 1 | 1 |
| RecursosInternos-DevOps | 3 | 0 | 5 |
| RecursosInternos-DevOps QA | 1 | 0 | 0 |
| Edv2 BR QA | 0 | 0 | 1 |

---

## 2. Critical Findings

### 2.1 🔴 CRITICAL: All App Services Missing Application Insights

**Finding:** All 72 App Services (Web Apps, Function Apps, API Apps) are missing the `APPLICATIONINSIGHTS_CONNECTION_STRING` app setting, meaning they are not sending telemetry to Application Insights.

**Impact:**
- No application-level monitoring (requests, dependencies, exceptions)
- No distributed tracing capabilities
- No performance insights (response times, failure rates)
- Blind to application errors and performance degradation

**Affected Resources:**

| App Type | Count | Examples |
|----------|-------|----------|
| Web App | 41 | wsmaeqaneuloran01, wsmaeexwussec01, wsevaexwustrzsave01 |
| Function App | 16 | fnrintrepeffqa, fnmaeqaneusincro, fnevaqaneumens01 |
| API App | 15 | wamaeqaneuaprmv01, waevaqaneunpe01, waevaexwusnpe01 |

**Resolution:**

1. **Deploy Application Insights** for each application or use shared instances per environment
2. **Configure connection string** via App Settings:

```bash
# For each App Service, add the connection string
az webapp config appsettings set \
  --name <app-name> \
  --resource-group <rg-name> \
  --settings APPLICATIONINSIGHTS_CONNECTION_STRING="InstrumentationKey=<key>;IngestionEndpoint=https://<region>.in.applicationinsights.azure.com/"

# For Function Apps
az functionapp config appsettings set \
  --name <function-name> \
  --resource-group <rg-name> \
  --settings APPLICATIONINSIGHTS_CONNECTION_STRING="InstrumentationKey=<key>;IngestionEndpoint=https://<region>.in.applicationinsights.azure.com/"
```

3. **Enable auto-instrumentation** (recommended for .NET, Java, Node.js, Python):

```bash
az webapp config appsettings set \
  --name <app-name> \
  --resource-group <rg-name> \
  --settings ApplicationInsightsAgent_EXTENSION_VERSION="~3" \
             XDT_MicrosoftApplicationInsights_Mode="recommended"
```

4. **Bicep/IaC approach** (recommended):

```bicep
resource webApp 'Microsoft.Web/sites@2022-09-01' = {
  name: webAppName
  // ... other properties
  properties: {
    siteConfig: {
      appSettings: [
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~3'
        }
      ]
    }
  }
}
```

---

### 2.2 🟠 HIGH: Missing Availability & Health Check Alerts

**Finding:** No availability tests or health check alerts configured for any App Service.

**Impact:**
- No proactive detection of service unavailability
- Delayed response to outages
- No SLA monitoring capability

**Resolution:**

1. **Create Availability Tests in Application Insights:**

```bash
# Create URL ping test for each critical endpoint
az monitor app-insights web-test create \
  --resource-group <rg-name> \
  --app-insights <app-insights-name> \
  --name "<app-name>-availability" \
  --location "North Europe" \
  --web-test-kind "ping" \
  --frequency 300 \
  --timeout 120 \
  --enabled true \
  --locations "[{\"Id\":\"emea-nl-ams-azr\"},{\"Id\":\"us-va-ash-azr\"}]" \
  --url "https://<app-name>.azurewebsites.net/health"
```

2. **Configure Health Check on App Service:**

```bash
# Enable health check for App Service
az webapp config set \
  --name <app-name> \
  --resource-group <rg-name> \
  --health-check-path "/health"
```

3. **Create Health Check Failed Alert:**

```bicep
resource healthCheckAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-${webAppName}-healthcheck-failed'
  location: 'global'
  properties: {
    severity: 1
    enabled: true
    scopes: [webApp.id]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HealthCheckStatus'
          metricName: 'HealthCheckStatus'
          operator: 'LessThan'
          threshold: 100
          timeAggregation: 'Average'
        }
      ]
    }
    actions: [{ actionGroupId: actionGroup.id }]
  }
}
```

---

### 2.3 🟠 HIGH: No Function App Specific Alerts

**Finding:** 16 Function Apps have no function-specific alerts (execution count, failures, duration).

**Impact:**
- No visibility into function execution health
- Cannot detect function failures or timeouts
- No scaling issues detection

**Affected Function Apps:**
- fnrintrepeffqa, fnrintrepeffpro
- fnmaeqaneusincro, fnmaeqaneudistreports1
- fnmaeqabrpnl01, fnmaepnlexwusapi01
- fnmaeexneudistreports01, fnglobalcreatejira
- fnevaqaneumens01, fnevaqaneumen01-stg
- fnevaqageneufn01, fnevaqageneufn02
- fnevageexneufn01, fnevageexneufn02
- fnevaexneumen01, fnS2Services

**Resolution - Essential Function App Alerts:**

```bicep
// 1. Function Execution Failures
resource functionFailuresAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-${functionAppName}-execution-failures'
  location: 'global'
  properties: {
    severity: 2
    enabled: true
    scopes: [functionApp.id]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'FunctionExecutionErrors'
          metricName: 'FunctionExecutionCount'
          dimensions: [{ name: 'Result', operator: 'Include', values: ['Failed'] }]
          operator: 'GreaterThan'
          threshold: 5
          timeAggregation: 'Total'
        }
      ]
    }
    actions: [{ actionGroupId: actionGroup.id }]
  }
}

// 2. Function Execution Duration (Timeout Warning)
resource functionDurationAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-${functionAppName}-execution-duration'
  location: 'global'
  properties: {
    severity: 3
    enabled: true
    scopes: [functionApp.id]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'FunctionExecutionUnits'
          metricName: 'FunctionExecutionUnits'
          operator: 'GreaterThan'
          threshold: 500000000  // Adjust based on function timeout
          timeAggregation: 'Average'
        }
      ]
    }
    actions: [{ actionGroupId: actionGroup.id }]
  }
}

// 3. Connection Count (for HTTP-triggered functions)
resource functionConnectionsAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-${functionAppName}-connections'
  location: 'global'
  properties: {
    severity: 2
    enabled: true
    scopes: [appServicePlan.id]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'TcpConnections'
          metricName: 'TcpConnections'
          operator: 'GreaterThan'
          threshold: 800  // Warning before hitting 1024 limit
          timeAggregation: 'Average'
        }
      ]
    }
    actions: [{ actionGroupId: actionGroup.id }]
  }
}
```

---

### 2.4 🟡 MEDIUM: Disabled Alert Rules

**Finding:** 22 alert rules are currently disabled (Enabled=False).

**Impact:**
- Monitoring gaps in production environments
- False sense of security with configured but inactive alerts

**Disabled Alerts:**

| Alert Name | Subscription | Resource |
|------------|--------------|----------|
| spevaexwusammaps01 – cpu | EVASM WUS PRO | Service Plan |
| wsevaexneutrzpnlapi01 – response time | EVASM NEU PRO | App Service |
| waevaexneummapsapi01 – response time | EVASM NEU PRO | App Service |
| SQL DATABASE SERVERLESS – WORKERS/LOG_IO/DATA_IO/CPU | EVASM (multiple) | SQL Database |
| COSDBEVAEXNEUNPE01 - RU CONSUMPTION | EVASM NEU PRO | Cosmos DB |
| Multiple "SIN USO" alerts | Various | Various |

**Resolution:**

```bash
# List all disabled alerts
az graph query -q "Resources 
| where type =~ 'microsoft.insights/metricalerts'
| where properties.enabled == false
| project name, subscriptionId, resourceGroup" \
  --subscriptions $ALL_SUBS --first 1000 --query "data" -o table

# Enable a specific alert
az monitor metrics alert update \
  --name "<alert-name>" \
  --resource-group <rg-name> \
  --enabled true

# Or delete if no longer needed (for "SIN USO" alerts)
az monitor metrics alert delete \
  --name "<alert-name>" \
  --resource-group <rg-name>
```

**Recommendation:** Review each disabled alert and either:
1. Enable if the resource is active
2. Delete if the resource/alert is obsolete
3. Update thresholds if they were disabled due to noise

---

## 3. Alert Coverage Analysis

### 3.1 Current Alert Distribution by Metric

| Metric | Count | Coverage |
|--------|-------|----------|
| HttpResponseTime | 24 | ✅ Good |
| MemoryPercentage | 23 | ✅ Good |
| Http5xx | 23 | ✅ Good |
| CpuPercentage | 23 | ✅ Good |
| requests | 18 | ⚠️ Partial |
| storage_percent | 17 | ✅ Good |
| threads | 10 | ⚠️ Partial |
| dtu_consumption_percent | 9 | ⚠️ Partial |
| TotalJob (Runbooks) | 8 | ✅ Good |

### 3.2 Missing Critical Alerts

| Alert Type | Coverage | Priority |
|------------|----------|----------|
| HealthCheckStatus | ❌ Missing | High |
| FunctionExecutionCount (Failed) | ❌ Missing | High |
| Requests (4xx errors) | ❌ Missing | High |
| RequestsInQueue | ❌ Missing | Medium |
| PrivateBytes | ❌ Missing | Medium |
| AverageMemoryWorkingSet | ❌ Missing | Medium |
| IoReadOperationsPerSecond | ❌ Missing | Low |

---

## 4. Recommended Alert Configuration

### 4.1 Essential App Service Alerts (Per Application)

```bicep
// Template for complete App Service monitoring
param appServiceName string
param appInsightsId string
param actionGroupId string

// 1. Response Time Alert (already exists for some, apply to all)
resource responseTimeAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-${appServiceName}-response-time'
  location: 'global'
  properties: {
    severity: 2
    enabled: true
    scopes: [resourceId('Microsoft.Web/sites', appServiceName)]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [{
        name: 'ResponseTime'
        metricName: 'HttpResponseTime'
        operator: 'GreaterThan'
        threshold: 5  // 5 seconds
        timeAggregation: 'Average'
      }]
    }
    actions: [{ actionGroupId: actionGroupId }]
  }
}

// 2. HTTP 5xx Errors (already exists for some, apply to all)
resource http5xxAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-${appServiceName}-http-5xx'
  location: 'global'
  properties: {
    severity: 2
    enabled: true
    scopes: [resourceId('Microsoft.Web/sites', appServiceName)]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [{
        name: 'Http5xxErrors'
        metricName: 'Http5xx'
        operator: 'GreaterThan'
        threshold: 10
        timeAggregation: 'Total'
      }]
    }
    actions: [{ actionGroupId: actionGroupId }]
  }
}

// 3. HTTP 4xx Errors (MISSING - Add this)
resource http4xxAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-${appServiceName}-http-4xx'
  location: 'global'
  properties: {
    severity: 3
    enabled: true
    scopes: [resourceId('Microsoft.Web/sites', appServiceName)]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [{
        name: 'Http4xxErrors'
        metricName: 'Http4xx'
        operator: 'GreaterThan'
        threshold: 50  // Adjust based on baseline
        timeAggregation: 'Total'
      }]
    }
    actions: [{ actionGroupId: actionGroupId }]
  }
}

// 4. Health Check Status (MISSING - Add this)
resource healthCheckAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-${appServiceName}-health-check'
  location: 'global'
  properties: {
    severity: 1
    enabled: true
    scopes: [resourceId('Microsoft.Web/sites', appServiceName)]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [{
        name: 'HealthCheckStatus'
        metricName: 'HealthCheckStatus'
        operator: 'LessThan'
        threshold: 100
        timeAggregation: 'Average'
      }]
    }
    actions: [{ actionGroupId: actionGroupId }]
  }
}

// 5. Requests in Queue (MISSING - Add this for early warning)
resource requestsInQueueAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-${appServiceName}-requests-queue'
  location: 'global'
  properties: {
    severity: 2
    enabled: true
    scopes: [resourceId('Microsoft.Web/sites', appServiceName)]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [{
        name: 'RequestsInQueue'
        metricName: 'RequestsInApplicationQueue'
        operator: 'GreaterThan'
        threshold: 100
        timeAggregation: 'Average'
      }]
    }
    actions: [{ actionGroupId: actionGroupId }]
  }
}
```

### 4.2 Essential Service Plan Alerts (Per Plan)

```bicep
// CPU and Memory alerts already exist for most plans
// Add these if missing:

// 1. Memory Working Set (more accurate than MemoryPercentage)
resource memoryWorkingSetAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-${servicePlanName}-memory-workingset'
  location: 'global'
  properties: {
    severity: 2
    enabled: true
    scopes: [resourceId('Microsoft.Web/serverfarms', servicePlanName)]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [{
        name: 'MemoryWorkingSet'
        metricName: 'AverageMemoryWorkingSet'
        operator: 'GreaterThan'
        threshold: 1073741824  // 1 GB - adjust based on plan size
        timeAggregation: 'Average'
      }]
    }
    actions: [{ actionGroupId: actionGroupId }]
  }
}
```

### 4.3 Application Insights-Based Alerts (Recommended)

Once Application Insights is configured, add these log-based alerts:

```bicep
// 1. Exception Rate Alert
resource exceptionAlert 'Microsoft.Insights/scheduledQueryRules@2022-08-01-preview' = {
  name: 'alert-${appServiceName}-exceptions'
  location: location
  properties: {
    severity: 2
    enabled: true
    scopes: [appInsightsId]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      allOf: [{
        query: '''
          exceptions
          | where cloud_RoleName == "${appServiceName}"
          | summarize ExceptionCount = count() by bin(timestamp, 5m)
        '''
        timeAggregation: 'Count'
        operator: 'GreaterThan'
        threshold: 10
        failingPeriods: {
          numberOfEvaluationPeriods: 3
          minFailingPeriodsToAlert: 2
        }
      }]
    }
    actions: { actionGroups: [actionGroupId] }
  }
}

// 2. Dependency Failure Alert
resource dependencyAlert 'Microsoft.Insights/scheduledQueryRules@2022-08-01-preview' = {
  name: 'alert-${appServiceName}-dependency-failures'
  location: location
  properties: {
    severity: 2
    enabled: true
    scopes: [appInsightsId]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      allOf: [{
        query: '''
          dependencies
          | where cloud_RoleName == "${appServiceName}"
          | where success == false
          | summarize FailedDependencies = count() by bin(timestamp, 5m), target
        '''
        timeAggregation: 'Count'
        operator: 'GreaterThan'
        threshold: 5
        failingPeriods: {
          numberOfEvaluationPeriods: 3
          minFailingPeriodsToAlert: 2
        }
      }]
    }
    actions: { actionGroups: [actionGroupId] }
  }
}

// 3. Slow Request Alert
resource slowRequestAlert 'Microsoft.Insights/scheduledQueryRules@2022-08-01-preview' = {
  name: 'alert-${appServiceName}-slow-requests'
  location: location
  properties: {
    severity: 3
    enabled: true
    scopes: [appInsightsId]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      allOf: [{
        query: '''
          requests
          | where cloud_RoleName == "${appServiceName}"
          | where duration > 5000  // 5 seconds
          | summarize SlowRequests = count() by bin(timestamp, 5m)
        '''
        timeAggregation: 'Count'
        operator: 'GreaterThan'
        threshold: 20
        failingPeriods: {
          numberOfEvaluationPeriods: 3
          minFailingPeriodsToAlert: 2
        }
      }]
    }
    actions: { actionGroups: [actionGroupId] }
  }
}
```

---

## 5. Remediation Priority

### Immediate Actions (This Week)

1. ✅ **Configure Application Insights** for all 72 App Services
2. ✅ **Enable Health Checks** on all Web Apps and API Apps
3. ✅ **Review and enable/delete** the 22 disabled alerts

### Short-Term (Next 2 Weeks)

4. ⏳ **Add missing metric alerts:**
   - HealthCheckStatus for all apps
   - Http4xx for all apps
   - FunctionExecutionCount for all Function Apps

5. ⏳ **Create Availability Tests** for critical endpoints

### Medium-Term (Next Month)

6. ⏳ **Implement Application Insights-based alerts** (after telemetry flows):
   - Exception rate alerts
   - Dependency failure alerts
   - Custom business metric alerts

7. ⏳ **Standardize alert naming convention** across subscriptions

---

## 6. Verification Commands

### Verify Application Insights Connection

```bash
# Check which apps have App Insights configured
az graph query -q "Resources
| where type =~ 'microsoft.web/sites'
| extend appType = case(kind contains 'functionapp', 'Function App', kind contains 'api', 'API App', 'Web App')
| mv-expand setting = properties.siteConfig.appSettings
| summarize hasAppInsights = countif(setting.name == 'APPLICATIONINSIGHTS_CONNECTION_STRING') by name, appType
| where hasAppInsights > 0
| project name, appType" \
  --subscriptions $ALL_SUBS --first 1000 --query "data" -o table
```

### Verify Health Check Configuration

```bash
# Check health check paths
az graph query -q "Resources
| where type =~ 'microsoft.web/sites'
| project name, subscriptionId, healthCheckPath=properties.siteConfig.healthCheckPath
| where isnotempty(healthCheckPath)" \
  --subscriptions $ALL_SUBS --first 1000 --query "data" -o table
```

### Count Alerts by Severity

```bash
az graph query -q "Resources
| where type in~ ('microsoft.insights/metricalerts', 'microsoft.insights/scheduledqueryrules')
| extend sev = tostring(properties.severity)
| summarize Total=count() by Severity=sev
| order by Severity asc" \
  --subscriptions $ALL_SUBS --first 1000 --query "data" -o table
```

---

## Appendix A: Alert Naming Convention Recommendation

**Pattern:** `ALERT RULE - <ENVIRONMENT> - <RESOURCE_TYPE> - <RESOURCE_NAME> - <METRIC>`

**Examples:**
- `ALERT RULE - PRO NEU - WEBAPP - wsmaeexneudist01 - RESPONSE TIME`
- `ALERT RULE - PRO NEU - FUNCTION - fnmaeexneudistreports01 - EXECUTION FAILURES`
- `ALERT RULE - PRO NEU - SERVICEPLAN - spmaeexneu01 - CPU`

---

## Appendix B: Reference Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Monitoring Architecture                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐    │
│  │  Web Apps    │     │ Function Apps│     │   API Apps   │    │
│  │    (41)      │     │     (16)     │     │     (15)     │    │
│  └──────┬───────┘     └──────┬───────┘     └──────┬───────┘    │
│         │                    │                    │             │
│         └────────────────────┼────────────────────┘             │
│                              │                                   │
│                              ▼                                   │
│              ┌───────────────────────────────┐                  │
│              │    Application Insights (27)  │                  │
│              │   ┌─────────────────────────┐ │                  │
│              │   │ • Requests & Exceptions │ │                  │
│              │   │ • Dependencies          │ │                  │
│              │   │ • Performance Metrics   │ │                  │
│              │   │ • Availability Tests    │ │                  │
│              │   └─────────────────────────┘ │                  │
│              └──────────────┬────────────────┘                  │
│                             │                                    │
│                             ▼                                    │
│              ┌───────────────────────────────┐                  │
│              │ Log Analytics Workspaces (26) │                  │
│              │   ┌─────────────────────────┐ │                  │
│              │   │ • Centralized Logs      │ │                  │
│              │   │ • KQL Queries           │ │                  │
│              │   │ • Workbooks             │ │                  │
│              │   └─────────────────────────┘ │                  │
│              └──────────────┬────────────────┘                  │
│                             │                                    │
│                             ▼                                    │
│              ┌───────────────────────────────┐                  │
│              │        Alert Rules            │                  │
│              │   ┌─────────────────────────┐ │                  │
│              │   │ • Metric Alerts (211)   │ │                  │
│              │   │ • Log Alerts (5)        │ │                  │
│              │   │ • Activity Log Alerts   │ │                  │
│              │   └─────────────────────────┘ │                  │
│              └──────────────┬────────────────┘                  │
│                             │                                    │
│                             ▼                                    │
│              ┌───────────────────────────────┐                  │
│              │       Action Groups           │                  │
│              │   ┌─────────────────────────┐ │                  │
│              │   │ • Email Notifications   │ │                  │
│              │   │ • SMS Alerts            │ │                  │
│              │   │ • Webhook Integrations  │ │                  │
│              │   │ • ITSM Integration      │ │                  │
│              │   └─────────────────────────┘ │                  │
│              └───────────────────────────────┘                  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

*Report generated by Azure Observability Strategies audit toolkit*
