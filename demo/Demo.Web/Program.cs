using Azure.Monitor.OpenTelemetry.AspNetCore;
using OpenTelemetry.Resources;
using System.Diagnostics;

var builder = WebApplication.CreateBuilder(args);

// ============================================================================
// OpenTelemetry Configuration - Azure Monitor Distro
// ============================================================================

var serviceName = "Demo.Web";
var serviceVersion = "1.0.0";
var environment = builder.Environment.EnvironmentName.ToLowerInvariant();

// Sampling ratio: 1.0 = 100%, 0.1 = 10%
// Priority: Environment variable > appsettings
var samplingRatio = float.TryParse(
    Environment.GetEnvironmentVariable("OTEL_SAMPLING_RATIO"),
    out var envSampling)
    ? envSampling
    : builder.Configuration.GetValue<float>("AzureMonitor:SamplingRatio", 1.0f);

// Configure OpenTelemetry with Azure Monitor
builder.Services.AddOpenTelemetry()
    .ConfigureResource(resource => resource
        .AddService(
            serviceName: serviceName,
            serviceVersion: serviceVersion)
        .AddAttributes(new Dictionary<string, object>
        {
            ["deployment.environment"] = environment,
            ["service.namespace"] = "distributed-tracing-demo"
        }))
    .UseAzureMonitor(options =>
    {
        // Connection string from environment (preferred) or config
        // NEVER use instrumentation keys - deprecated
        options.ConnectionString = Environment.GetEnvironmentVariable("APPLICATIONINSIGHTS_CONNECTION_STRING")
            ?? builder.Configuration["ApplicationInsights:ConnectionString"];
        
        options.SamplingRatio = samplingRatio;
    });

// ============================================================================
// HttpClient Factory - Required for correlation propagation
// ============================================================================

builder.Services.AddHttpClient("DemoApi", client =>
{
    var apiBaseUrl = builder.Configuration["Services:ApiBaseUrl"] ?? "http://localhost:5002";
    client.BaseAddress = new Uri(apiBaseUrl);
    client.Timeout = TimeSpan.FromSeconds(30);
});

// ============================================================================
// Logging Configuration
// ============================================================================

builder.Logging.AddConfiguration(builder.Configuration.GetSection("Logging"));

var app = builder.Build();

// ============================================================================
// Endpoints
// ============================================================================

// Health check endpoint
app.MapGet("/health", () => Results.Ok(new { status = "healthy", service = serviceName }));

// Test endpoint for alert verification - triggers 5xx error
app.MapGet("/test-error", (ILogger<Program> logger) =>
{
    var traceId = Activity.Current?.TraceId.ToString() ?? "unknown";
    logger.LogError("Test error triggered for alert verification: TraceId={TraceId}", traceId);
    return Results.Problem(
        title: "Test Error",
        statusCode: 500,
        detail: "This error was intentionally triggered for alert testing.");
});

// Main demo endpoint - triggers the distributed trace
app.MapGet("/demo", async (IHttpClientFactory httpClientFactory, ILogger<Program> logger) =>
{
    var stopwatch = Stopwatch.StartNew();
    
    // Generate synthetic order ID (safe to log - not PII)
    var orderId = Guid.NewGuid();
    
    // Get current trace ID for correlation (safe to log)
    var traceId = Activity.Current?.TraceId.ToString() ?? "unknown";
    
    // ✅ GOOD: Structured logging with safe fields only
    logger.LogInformation(
        "Demo request started: TraceId={TraceId}, OrderId={OrderId}",
        traceId,
        orderId);
    
    try
    {
        // Call Demo.Api - HttpClient automatically propagates trace context
        var client = httpClientFactory.CreateClient("DemoApi");
        var apiResponse = await client.GetFromJsonAsync<ApiResponse>($"/orders/{orderId}");
        
        stopwatch.Stop();
        
        // ✅ GOOD: Log completion with safe metrics
        logger.LogInformation(
            "Demo request completed: TraceId={TraceId}, OrderId={OrderId}, Duration={Duration}ms, Status={Status}",
            traceId,
            orderId,
            stopwatch.ElapsedMilliseconds,
            "success");
        
        // Return combined response with trace context for verification
        return Results.Ok(new
        {
            traceId,
            orderId,
            web = new
            {
                service = serviceName,
                timestamp = DateTime.UtcNow
            },
            api = apiResponse
        });
    }
    catch (Exception ex)
    {
        stopwatch.Stop();
        
        // ✅ GOOD: Log error with safe fields only (no exception details with potential PII)
        logger.LogError(
            "Demo request failed: TraceId={TraceId}, OrderId={OrderId}, Duration={Duration}ms, ErrorType={ErrorType}",
            traceId,
            orderId,
            stopwatch.ElapsedMilliseconds,
            ex.GetType().Name);
        
        return Results.Problem(
            title: "Service unavailable",
            statusCode: 503,
            detail: "Unable to complete the request. Please try again.");
    }
});

app.Run();

// ============================================================================
// Response Models (no PII)
// ============================================================================

record ApiResponse(
    string Service,
    Guid OrderId,
    string Status,
    EnrichmentResponse? Enrichment
);

record EnrichmentResponse(
    string Service,
    Guid OrderId,
    string Priority,
    string Region,
    bool StorageChecked
);
