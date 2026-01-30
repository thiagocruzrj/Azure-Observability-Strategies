// ============================================================================
// Security & Governance Module for Observability
// Part of the Monitoring Golden Path
// ============================================================================
//
// PURPOSE
// -------
// This module establishes baseline security controls for the monitoring stack:
// - RBAC role assignments for monitoring access (read-only vs. contributor)
// - Scoped at the monitoring Resource Group level (least privilege)
//
// RBAC MODEL
// ----------
// Two access levels are defined:
//
// 1. Monitoring Readers (read-only)
//    - Can view logs, metrics, dashboards, workbooks
//    - Cannot modify alerts, diagnostic settings, or configurations
//    - Roles assigned:
//      * Monitoring Reader (covers LAW + App Insights + Alerts)
//
// 2. Monitoring Contributors
//    - Can view and modify alerts, workbooks, diagnostic settings
//    - Cannot manage RBAC or delete core resources
//    - Roles assigned:
//      * Monitoring Contributor (covers LAW + App Insights + Alerts)
//
// SCOPE
// -----
// All role assignments are scoped to the monitoring Resource Group only.
// This follows least-privilege principles and avoids subscription-wide access.
//
// ============================================================================

// ============================================================================
// Parameters
// ============================================================================

@description('Array of Azure AD principal IDs (users, groups, or service principals) for read-only monitoring access')
param monitoringReadersPrincipalIds array = []

@description('Array of Azure AD principal IDs (users, groups, or service principals) for monitoring contributor access')
param monitoringContributorsPrincipalIds array = []

@description('Principal type for readers (User, Group, or ServicePrincipal)')
@allowed(['User', 'Group', 'ServicePrincipal'])
param readersPrincipalType string = 'Group'

@description('Principal type for contributors (User, Group, or ServicePrincipal)')
@allowed(['User', 'Group', 'ServicePrincipal'])
param contributorsPrincipalType string = 'Group'

// ============================================================================
// Variables - Built-in Role Definition IDs
// ============================================================================

// Azure built-in role definition IDs
// Reference: https://learn.microsoft.com/azure/role-based-access-control/built-in-roles

// Monitoring Reader - Read-only access to monitoring data (metrics, logs, alerts)
// Includes: Log Analytics Reader + Application Insights Component Reader + Alert Rules Reader
var monitoringReaderRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '43d0d8ad-25c7-4714-9337-8ba259a9fe05')

// Monitoring Contributor - Full access to monitoring configurations
// Includes: Log Analytics Contributor + Application Insights Contributor + Alert Rules Contributor
var monitoringContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '749f88d5-cbae-40b8-bcfc-e573ddc772fa')

// ============================================================================
// Role Assignments - Monitoring Readers
// ============================================================================

// Assign Monitoring Reader role to each reader principal
// Uses deterministic GUID based on resource group, role, and principal ID
resource monitoringReaderAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for principalId in monitoringReadersPrincipalIds: {
  name: guid(resourceGroup().id, monitoringReaderRoleId, principalId)
  properties: {
    roleDefinitionId: monitoringReaderRoleId
    principalId: principalId
    principalType: readersPrincipalType
    description: 'Monitoring Reader access for observability - assigned via Monitoring Golden Path'
  }
}]

// ============================================================================
// Role Assignments - Monitoring Contributors
// ============================================================================

// Assign Monitoring Contributor role to each contributor principal
// Uses deterministic GUID based on resource group, role, and principal ID
resource monitoringContributorAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for principalId in monitoringContributorsPrincipalIds: {
  name: guid(resourceGroup().id, monitoringContributorRoleId, principalId)
  properties: {
    roleDefinitionId: monitoringContributorRoleId
    principalId: principalId
    principalType: contributorsPrincipalType
    description: 'Monitoring Contributor access for observability - assigned via Monitoring Golden Path'
  }
}]

// ============================================================================
// Outputs
// ============================================================================

@description('Array of role assignment IDs for monitoring readers')
output readerRoleAssignmentIds array = [for (principalId, index) in monitoringReadersPrincipalIds: monitoringReaderAssignments[index].id]

@description('Array of role assignment IDs for monitoring contributors')
output contributorRoleAssignmentIds array = [for (principalId, index) in monitoringContributorsPrincipalIds: monitoringContributorAssignments[index].id]

@description('Total number of role assignments created')
output totalRoleAssignments int = length(monitoringReadersPrincipalIds) + length(monitoringContributorsPrincipalIds)

// ============================================================================
// ============================================================================
//
//                    TELEMETRY PII POLICY
//                    ====================
//
// This section documents the mandatory PII governance rules for all telemetry
// sent to Application Insights and Log Analytics. This is a POLICY document,
// not enforced via Bicep - developers MUST follow these rules in code.
//
// ============================================================================
//
// PRINCIPLE: DEFAULT DENY
// -----------------------
// All personally identifiable information (PII) is FORBIDDEN in telemetry
// unless explicitly approved through the exception process.
//
// ============================================================================
//
// FORBIDDEN DATA (never log)
// --------------------------
// The following data types must NEVER appear in telemetry:
//
// 1. IDENTITY DATA
//    - Full names, usernames, display names
//    - Email addresses
//    - Phone numbers
//    - Physical addresses
//    - IP addresses (use anonymization if needed for geo)
//
// 2. GOVERNMENT IDENTIFIERS
//    - Social Security Numbers (SSN)
//    - National ID numbers
//    - Passport numbers
//    - Driver's license numbers
//    - Tax identification numbers
//
// 3. AUTHENTICATION & AUTHORIZATION
//    - Passwords (plaintext or hashed)
//    - API keys, secrets, connection strings
//    - JWT tokens, bearer tokens
//    - Session IDs, authentication cookies
//    - Authorization headers
//    - OAuth tokens (access, refresh, ID tokens)
//
// 4. SENSITIVE HEADERS
//    - Authorization
//    - Cookie
//    - Set-Cookie
//    - X-API-Key
//    - X-Auth-Token
//    - Any custom auth headers
//
// 5. REQUEST/RESPONSE BODIES
//    - Full request bodies (may contain PII)
//    - Full response bodies (may contain PII)
//    - Form data
//    - File uploads
//
// 6. FINANCIAL DATA
//    - Credit card numbers
//    - Bank account numbers
//    - Financial transaction details with identifiers
//
// ============================================================================
//
// ALLOWED DATA (safe to log)
// --------------------------
// The following data is permitted in telemetry:
//
// 1. OPERATIONAL METADATA
//    - Operation names (e.g., "GetUser", "CreateOrder")
//    - HTTP methods (GET, POST, PUT, DELETE)
//    - Status codes (200, 404, 500)
//    - Response durations / latency (ms)
//    - Request/response sizes (bytes, not content)
//
// 2. ROUTE INFORMATION
//    - Route templates: /api/users/{id}  ✅
//    - NOT raw URLs: /api/users/john.doe@email.com  ❌
//    - Controller/action names
//    - API versions
//
// 3. SYNTHETIC IDENTIFIERS
//    - Correlation IDs (X-Correlation-ID)
//    - Trace IDs (W3C traceparent)
//    - Span IDs
//    - Request IDs (internal GUIDs)
//    - Session correlation tokens (NOT session cookies)
//
// 4. DEPENDENCY INFORMATION
//    - Dependency type (SQL, HTTP, Redis, etc.)
//    - Target hostname (e.g., sql-server.database.windows.net)
//    - Success/failure status
//    - Duration
//    - NOT: connection strings, queries with PII
//
// 5. INFRASTRUCTURE DATA
//    - Cloud role name
//    - Instance ID
//    - Region
//    - Environment (dev/staging/prod)
//    - Deployment version
//
// 6. BUSINESS METRICS (anonymized)
//    - Order count (not order details)
//    - Error counts by type
//    - Feature usage flags
//    - A/B test variant (not user assignment)
//
// ============================================================================
//
// IMPLEMENTATION GUIDANCE: ASP.NET Core
// -------------------------------------
//
// 1. STRUCTURED LOGGING (DO)
//    
//    // ✅ GOOD - Structured with safe properties
//    _logger.LogInformation(
//        "Order processed: OrderId={OrderId}, Amount={Amount}, Status={Status}",
//        order.Id,           // Internal GUID, not customer ID
//        order.TotalAmount,  // Numeric value
//        order.Status);      // Enum/string
//    
//    // ❌ BAD - Contains PII
//    _logger.LogInformation($"Order for {customer.Email}: {JsonSerializer.Serialize(order)}");
//
//
// 2. HEADER FILTERING
//    
//    // In Program.cs or Startup.cs - configure safe headers only
//    builder.Services.AddApplicationInsightsTelemetry(options =>
//    {
//        // Don't collect request headers by default
//    });
//    
//    // If you need specific headers, allowlist them:
//    services.AddApplicationInsightsTelemetryProcessor<SafeHeaderProcessor>();
//    
//    public class SafeHeaderProcessor : ITelemetryProcessor
//    {
//        private static readonly HashSet<string> AllowedHeaders = new(StringComparer.OrdinalIgnoreCase)
//        {
//            "Content-Type",
//            "Accept",
//            "X-Correlation-ID",
//            "X-Request-ID"
//        };
//        // Filter implementation...
//    }
//
//
// 3. URL SCRUBBING
//    
//    // Use telemetry initializer to sanitize URLs
//    public class UrlSanitizingInitializer : ITelemetryInitializer
//    {
//        public void Initialize(ITelemetry telemetry)
//        {
//            if (telemetry is RequestTelemetry request)
//            {
//                // Replace email-like patterns in URL
//                request.Url = SanitizeUrl(request.Url);
//                request.Name = SanitizeRouteName(request.Name);
//            }
//        }
//        
//        private Uri SanitizeUrl(Uri url)
//        {
//            // Replace /users/john@email.com with /users/{email}
//            // Replace /orders/12345 with /orders/{id}
//            // Implementation depends on your routes
//        }
//    }
//
//
// 4. EXCEPTION HANDLING
//    
//    // ✅ GOOD - Safe exception logging
//    try { /* ... */ }
//    catch (Exception ex)
//    {
//        _logger.LogError(ex, 
//            "Failed to process order {OrderId}", 
//            orderId);  // Log ID only, not full object
//    }
//    
//    // ❌ BAD - Exception message may contain PII
//    catch (Exception ex)
//    {
//        _logger.LogError($"Error for user {userEmail}: {ex}");
//    }
//
//
// 5. HTTP CLIENT LOGGING
//    
//    // Disable body logging in HttpClient
//    builder.Services.AddHttpClient("api")
//        .ConfigurePrimaryHttpMessageHandler(() => new HttpClientHandler())
//        // Don't add logging handlers that capture bodies
//
// ============================================================================
//
// IMPLEMENTATION GUIDANCE: Azure Functions
// ----------------------------------------
//
// 1. FUNCTION INPUT/OUTPUT BINDINGS
//    
//    // ❌ BAD - Logging entire binding data
//    [Function("ProcessOrder")]
//    public async Task Run(
//        [QueueTrigger("orders")] Order order,
//        FunctionContext context)
//    {
//        _logger.LogInformation("Processing: {Order}", JsonSerializer.Serialize(order));
//    }
//    
//    // ✅ GOOD - Logging safe identifiers only
//    [Function("ProcessOrder")]
//    public async Task Run(
//        [QueueTrigger("orders")] Order order,
//        FunctionContext context)
//    {
//        _logger.LogInformation(
//            "Processing order: OrderId={OrderId}, ItemCount={ItemCount}",
//            order.Id,
//            order.Items.Count);
//    }
//
//
// 2. HOST.JSON LOG LEVELS
//    
//    {
//      "logging": {
//        "logLevel": {
//          "default": "Information",
//          "Microsoft.Azure.WebJobs.Host.Bindings": "Warning",  // Reduce binding noise
//          "System.Net.Http.HttpClient": "Warning"  // Don't log HTTP details
//        }
//      }
//    }
//
//
// 3. DURABLE FUNCTIONS
//    
//    // ❌ BAD - Orchestration input may contain PII
//    _logger.LogInformation("Starting orchestration with: {Input}", input);
//    
//    // ✅ GOOD - Log correlation only
//    _logger.LogInformation(
//        "Starting orchestration: InstanceId={InstanceId}, Type={Type}",
//        context.InstanceId,
//        input.GetType().Name);
//
// ============================================================================
//
// EXCEPTION PROCESS
// -----------------
// If you have a legitimate business need to log PII:
//
// 1. Document the specific data and business justification
// 2. Submit request to Security/Compliance team
// 3. If approved:
//    - Implement data minimization (log only what's needed)
//    - Set explicit retention period (shorter than default)
//    - Apply access controls (restrict who can query)
//    - Consider separate LAW table with different retention
// 4. Document approval in code comments with ticket reference
//
// Example approved exception comment:
//
//    // PII EXCEPTION: SEC-2024-1234
//    // Approved: 2024-06-15, Expires: 2025-06-15
//    // Justification: Fraud detection requires correlation of email patterns
//    // Data: Hashed email (SHA256, not reversible)
//    // Retention: 30 days
//    _logger.LogInformation("Fraud check: EmailHash={Hash}", hashedEmail);
//
// ============================================================================
//
// VERIFICATION CHECKLIST
// ----------------------
// Before deploying any service, verify:
//
// [ ] No PII in custom telemetry properties
// [ ] No PII in exception messages or stack traces
// [ ] No request/response body logging
// [ ] No sensitive header logging
// [ ] URLs use route templates, not raw paths with identifiers
// [ ] Log levels appropriate (no Debug/Trace in production)
// [ ] HttpClient logging doesn't capture bodies
// [ ] Queue/Event messages logged by ID only
//
// ============================================================================
//
// REFERENCES
// ----------
// - Azure Monitor data security: https://learn.microsoft.com/azure/azure-monitor/logs/data-security
// - Application Insights data collection: https://learn.microsoft.com/azure/azure-monitor/app/data-retention-privacy
// - GDPR compliance for telemetry: https://learn.microsoft.com/azure/azure-monitor/logs/personal-data-mgmt
//
// ============================================================================
