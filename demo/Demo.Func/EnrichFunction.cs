using System.Diagnostics;
using Azure.Storage.Blobs;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace Demo.Func;

/// <summary>
/// Enrichment function that demonstrates:
/// - End-to-end distributed tracing (trace context propagated from upstream services)
/// - Structured logging with safe fields (no PII)
/// - Optional external dependency (Azure Blob Storage)
/// </summary>
public class EnrichFunction
{
    private const string ServiceName = "Demo.Func";
    
    private readonly ILogger<EnrichFunction> _logger;
    private readonly IConfiguration _configuration;
    private readonly BlobServiceClient? _blobServiceClient;

    public EnrichFunction(
        ILogger<EnrichFunction> logger,
        IConfiguration configuration,
        BlobServiceClient? blobServiceClient = null)
    {
        _logger = logger;
        _configuration = configuration;
        _blobServiceClient = blobServiceClient;
    }

    /// <summary>
    /// GET /api/enrich?orderId={guid}
    /// Returns enrichment data for an order
    /// </summary>
    [Function("Enrich")]
    public async Task<IActionResult> Run(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "enrich")] HttpRequest req)
    {
        var stopwatch = Stopwatch.StartNew();
        
        // Get trace context (automatically propagated by Functions host with OTel mode)
        var traceId = Activity.Current?.TraceId.ToString() ?? "unknown";
        
        // Parse orderId from query string
        if (!Guid.TryParse(req.Query["orderId"], out var orderId))
        {
            // ✅ GOOD: Log validation failure without sensitive data
            _logger.LogWarning(
                "Invalid orderId format: TraceId={TraceId}",
                traceId);
            
            return new BadRequestObjectResult(new { error = "Invalid orderId format" });
        }
        
        // ✅ GOOD: Structured logging with safe fields
        _logger.LogInformation(
            "Enrichment started: TraceId={TraceId}, OrderId={OrderId}",
            traceId,
            orderId);
        
        // Determine enrichment values (in real app, this might come from database/cache)
        var priority = DeterminePriority(orderId);
        var region = DetermineRegion(orderId);
        var storageChecked = false;
        
        // Optional: Check Azure Blob Storage dependency
        var enableStorage = _configuration["ENABLE_STORAGE_DEPENDENCY"] == "true";
        if (enableStorage && _blobServiceClient != null)
        {
            storageChecked = await CheckStorageDependencyAsync(traceId, orderId);
        }
        
        stopwatch.Stop();
        
        // ✅ GOOD: Log completion with safe metrics
        _logger.LogInformation(
            "Enrichment completed: TraceId={TraceId}, OrderId={OrderId}, Duration={Duration}ms, Priority={Priority}, StorageChecked={StorageChecked}",
            traceId,
            orderId,
            stopwatch.ElapsedMilliseconds,
            priority,
            storageChecked);
        
        return new OkObjectResult(new EnrichmentResponse(
            Service: ServiceName,
            OrderId: orderId,
            Priority: priority,
            Region: region,
            StorageChecked: storageChecked
        ));
    }

    /// <summary>
    /// Demonstrates an external dependency call (Azure Blob Storage)
    /// This will appear as a dependency in Application Insights
    /// </summary>
    private async Task<bool> CheckStorageDependencyAsync(string traceId, Guid orderId)
    {
        try
        {
            var containerName = _configuration["STORAGE_CONTAINER_NAME"] ?? "demo-container";
            var blobName = _configuration["STORAGE_BLOB_NAME"] ?? "enrichment-config.json";
            
            _logger.LogDebug(
                "Checking storage: TraceId={TraceId}, Container={Container}, Blob={Blob}",
                traceId,
                containerName,
                blobName);
            
            var containerClient = _blobServiceClient!.GetBlobContainerClient(containerName);
            var blobClient = containerClient.GetBlobClient(blobName);
            
            // Just check if blob exists (don't read content - might contain sensitive data)
            var exists = await blobClient.ExistsAsync();
            
            _logger.LogDebug(
                "Storage check completed: TraceId={TraceId}, BlobExists={Exists}",
                traceId,
                exists.Value);
            
            return exists.Value;
        }
        catch (Exception ex)
        {
            // ✅ GOOD: Log error without sensitive details
            _logger.LogWarning(
                "Storage check failed: TraceId={TraceId}, ErrorType={ErrorType}",
                traceId,
                ex.GetType().Name);
            
            return false;
        }
    }

    /// <summary>
    /// Determine order priority based on orderId (demo logic)
    /// In real app, this would query a database or rules engine
    /// </summary>
    private static string DeterminePriority(Guid orderId)
    {
        // Simple hash-based logic for demo
        var hash = orderId.GetHashCode();
        return (hash % 3) switch
        {
            0 => "high",
            1 => "standard",
            _ => "low"
        };
    }

    /// <summary>
    /// Determine region based on orderId (demo logic)
    /// In real app, this would be based on customer location
    /// </summary>
    private static string DetermineRegion(Guid orderId)
    {
        var hash = orderId.GetHashCode();
        return (Math.Abs(hash) % 4) switch
        {
            0 => "us-east",
            1 => "us-west",
            2 => "eu-west",
            _ => "ap-southeast"
        };
    }
}

// ============================================================================
// Response Models (no PII)
// ============================================================================

public record EnrichmentResponse(
    string Service,
    Guid OrderId,
    string Priority,
    string Region,
    bool StorageChecked
);
