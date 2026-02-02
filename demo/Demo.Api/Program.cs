using Azure.Monitor.OpenTelemetry.AspNetCore;
using OpenTelemetry.Resources;
using System.Diagnostics;

var builder = WebApplication.CreateBuilder(args);

// ============================================================================
// OpenTelemetry Configuration - Azure Monitor Distro
// ============================================================================

var serviceName = "Demo.Api";
var serviceVersion = "1.0.0";
var environment = builder.Environment.EnvironmentName.ToLowerInvariant();

// Sampling ratio from config or environment
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
        options.ConnectionString = Environment.GetEnvironmentVariable("APPLICATIONINSIGHTS_CONNECTION_STRING")
            ?? builder.Configuration["ApplicationInsights:ConnectionString"];
        
        options.SamplingRatio = samplingRatio;
    });

// ============================================================================
// HttpClient Factory - For calling Azure Functions
// ============================================================================

builder.Services.AddHttpClient("DemoFunc", client =>
{
    var funcBaseUrl = builder.Configuration["Services:FuncBaseUrl"] ?? "http://localhost:7073";
    client.BaseAddress = new Uri(funcBaseUrl);
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

// Health check
app.MapGet("/health", () => Results.Ok(new { status = "healthy", service = serviceName }));

// Orders endpoint - receives calls from Demo.Web, calls Demo.Func
app.MapGet("/orders/{orderId:guid}", async (
    Guid orderId,
    IHttpClientFactory httpClientFactory,
    ILogger<Program> logger) =>
{
    var stopwatch = Stopwatch.StartNew();
    var traceId = Activity.Current?.TraceId.ToString() ?? "unknown";
    
    // ✅ GOOD: Structured logging with safe fields
    logger.LogInformation(
        "Order request received: TraceId={TraceId}, OrderId={OrderId}",
        traceId,
        orderId);
    
    try
    {
        // Call Demo.Func for enrichment
        var client = httpClientFactory.CreateClient("DemoFunc");
        var enrichmentResponse = await client.GetFromJsonAsync<EnrichmentResponse>(
            $"/api/enrich?orderId={orderId}");
        
        stopwatch.Stop();
        
        // ✅ GOOD: Log completion with metrics
        logger.LogInformation(
            "Order processed: TraceId={TraceId}, OrderId={OrderId}, Duration={Duration}ms, Status={Status}",
            traceId,
            orderId,
            stopwatch.ElapsedMilliseconds,
            "processed");
        
        return Results.Ok(new ApiResponse(
            Service: serviceName,
            OrderId: orderId,
            Status: "processed",
            Enrichment: enrichmentResponse
        ));
    }
    catch (HttpRequestException)
    {
        stopwatch.Stop();
        
        // ✅ GOOD: Log error without sensitive details
        logger.LogWarning(
            "Enrichment service unavailable: TraceId={TraceId}, OrderId={OrderId}, Duration={Duration}ms",
            traceId,
            orderId,
            stopwatch.ElapsedMilliseconds);
        
        // Return partial response without enrichment
        return Results.Ok(new ApiResponse(
            Service: serviceName,
            OrderId: orderId,
            Status: "processed-without-enrichment",
            Enrichment: null
        ));
    }
    catch (Exception ex)
    {
        stopwatch.Stop();
        
        logger.LogError(
            "Order processing failed: TraceId={TraceId}, OrderId={OrderId}, Duration={Duration}ms, ErrorType={ErrorType}",
            traceId,
            orderId,
            stopwatch.ElapsedMilliseconds,
            ex.GetType().Name);
        
        return Results.Problem(
            title: "Processing error",
            statusCode: 500,
            detail: "Unable to process the order.");
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
