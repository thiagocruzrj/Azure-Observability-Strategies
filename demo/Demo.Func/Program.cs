using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Azure.Storage.Blobs;

var host = new HostBuilder()
    .ConfigureFunctionsWebApplication()
    .ConfigureServices((context, services) =>
    {
        // ============================================================================
        // Application Insights Integration for .NET Isolated Worker
        // ============================================================================
        // NOTE: host.json has "telemetryMode": "OpenTelemetry" which handles tracing
        // ConfigureFunctionsApplicationInsights ensures worker logs flow to the host
        services.ConfigureFunctionsApplicationInsights();
        
        // ============================================================================
        // Optional: Azure Blob Storage Client
        // ============================================================================
        var enableStorage = context.Configuration["ENABLE_STORAGE_DEPENDENCY"] == "true";
        if (enableStorage)
        {
            var storageConnectionString = context.Configuration["STORAGE_CONNECTION_STRING"];
            if (!string.IsNullOrEmpty(storageConnectionString))
            {
                services.AddSingleton(new BlobServiceClient(storageConnectionString));
            }
        }
    })
    .Build();

host.Run();
