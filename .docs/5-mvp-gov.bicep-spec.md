# Step E — Minimum Viable Governance (Fast, But Real)

## Status: BICEP MODULE READY

Security module: `modules/security-observability.bicep`

---

## 1. RBAC Separation (at RG Scope)

Apply role assignments at `rg-obs-demo-dev-weu`:

### Monitoring Readers Group

| Role | Role Definition ID | Purpose |
|------|-------------------|---------|
| Log Analytics Reader | `73c42c96-874c-492b-b04d-ab87d138a893` | Read LAW data |
| Monitoring Reader | `43d0d8ad-25c7-4714-9337-8ba259a9fe05` | Read metrics & alerts |

### Monitoring Contributors Group

| Role | Role Definition ID | Purpose |
|------|-------------------|---------|
| Log Analytics Contributor | `92aaf0da-9dab-42b6-94a3-d43ce8d16293` | Manage LAW |
| Monitoring Contributor | `749f88d5-cbae-40b8-bcfc-e573ddc772fa` | Manage metrics & alerts |

### Bicep Implementation

```bicep
// Example from modules/security-observability.bicep
resource monitoringReaderRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, monitoringReadersPrincipalId, monitoringReaderRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', monitoringReaderRoleId)
    principalId: monitoringReadersPrincipalId
    principalType: 'Group'
  }
}
```

> ✅ **Best Practice**: Keep scope at RG level (don't go subscription-wide for demos)

---

## 2. PII Rule (Document + Demonstrate)

### Policy Statement

| Category | Rule |
|----------|------|
| **Default** | No PII in telemetry |
| **Never Log** | Request/response bodies, `Authorization`/`Cookie` headers, emails, names, tokens, IP addresses |
| **Allowed** | Route templates, status codes, latency, dependency targets, trace IDs, synthetic IDs (GUIDs) |

### Safe Structured Logging Example

```csharp
// ✅ GOOD: Safe telemetry (no PII)
logger.LogInformation(
    "Order processed: TraceId={TraceId}, OrderId={OrderId}, Duration={Duration}ms, Status={Status}",
    Activity.Current?.TraceId.ToString(),
    orderId,           // Synthetic GUID - not PII
    stopwatch.ElapsedMilliseconds,
    "success");

// ❌ BAD: Contains PII
logger.LogInformation(
    "Order for {CustomerEmail} processed, Auth: {AuthHeader}",
    customer.Email,    // PII!
    request.Headers["Authorization"]);  // Credential!
```

### Code Implementation (from demo)

```csharp
// Demo.Api/Program.cs - Example of PII-safe logging
app.MapGet("/orders/{orderId:guid}", async (
    Guid orderId,
    IHttpClientFactory httpClientFactory,
    ILogger<Program> logger) =>
{
    var traceId = Activity.Current?.TraceId.ToString() ?? "no-trace";
    var stopwatch = Stopwatch.StartNew();
    
    // ✅ Only log: traceId, orderId (synthetic), duration, status
    logger.LogInformation(
        "Processing order: TraceId={TraceId}, OrderId={OrderId}",
        traceId,
        orderId);
    
    // ... process order ...
    
    stopwatch.Stop();
    logger.LogInformation(
        "Order completed: TraceId={TraceId}, OrderId={OrderId}, Duration={Duration}ms",
        traceId,
        orderId,
        stopwatch.ElapsedMilliseconds);
});
```

---

## 3. PII Categories Reference

### 🚫 NEVER Log (High Risk)

| Data Type | Examples | Risk |
|-----------|----------|------|
| Authentication | Bearer tokens, API keys, passwords | Credential theft |
| Personal Identity | Email, name, SSN, phone | GDPR/CCPA violation |
| Payment | Credit card, bank account | PCI-DSS violation |
| Health | Medical records, diagnoses | HIPAA violation |
| Location | GPS coordinates, home address | Privacy violation |

### ✅ SAFE to Log

| Data Type | Examples | Why Safe |
|-----------|----------|----------|
| Synthetic IDs | GUIDs, correlation IDs | Not linkable to person |
| Technical Metrics | Latency, status codes, byte counts | No personal data |
| Route Templates | `/api/orders/{id}` | Pattern, not actual values |
| Timestamps | ISO 8601 dates | Technical metadata |
| Service Names | `Demo.Api`, `Demo.Func` | Infrastructure info |

---

## 4. Deployment

```bash
# Deploy security/governance module
az deployment group create \
  --resource-group rg-obs-demo-dev-weu \
  --template-file modules/security-observability.bicep \
  --parameters \
    monitoringReadersPrincipalId="<AAD-GROUP-ID>" \
    monitoringContributorsPrincipalId="<AAD-GROUP-ID>"
```

---

## 5. Compliance Verification

```kusto
// Audit query: Find potential PII in logs
traces
| where timestamp > ago(24h)
| where message has_any ("@", "Bearer", "password", "email", "Authorization")
| project timestamp, message, cloud_RoleName
| take 100
```
