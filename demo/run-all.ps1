# ============================================================================
# Run All Services Script (Windows PowerShell)
# ============================================================================
# This script starts all three services in separate windows.
# Close the windows or press Ctrl+C in each to stop.
# ============================================================================

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Distributed Tracing Demo - Starting Services" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Check for required tools
if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: .NET SDK not found. Please install .NET 8 SDK." -ForegroundColor Red
    exit 1
}

if (-not (Get-Command func -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: Azure Functions Core Tools not found." -ForegroundColor Red
    Write-Host "Install with: npm install -g azure-functions-core-tools@4" -ForegroundColor Yellow
    exit 1
}

# Build all projects first
Write-Host "[1/4] Building projects..." -ForegroundColor Yellow
dotnet build "$ScriptDir\DistributedTracingDemo.sln" --configuration Debug --verbosity minimal

Write-Host ""
Write-Host "[2/4] Starting Demo.Func on port 7073..." -ForegroundColor Yellow
Start-Process -FilePath "cmd" -ArgumentList "/k", "cd /d `"$ScriptDir\Demo.Func`" && func start --port 7073" -WindowStyle Normal

# Wait for Functions to start
Start-Sleep -Seconds 5

Write-Host ""
Write-Host "[3/4] Starting Demo.Api on port 5002..." -ForegroundColor Yellow
Start-Process -FilePath "cmd" -ArgumentList "/k", "cd /d `"$ScriptDir\Demo.Api`" && dotnet run --no-build --urls http://localhost:5002" -WindowStyle Normal

# Wait for API to start
Start-Sleep -Seconds 3

Write-Host ""
Write-Host "[4/4] Starting Demo.Web on port 5001..." -ForegroundColor Yellow
Start-Process -FilePath "cmd" -ArgumentList "/k", "cd /d `"$ScriptDir\Demo.Web`" && dotnet run --no-build --urls http://localhost:5001" -WindowStyle Normal

# Wait for Web to start
Start-Sleep -Seconds 3

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "All services started!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Endpoints:" -ForegroundColor Cyan
Write-Host "  Demo.Web:  http://localhost:5001/demo"
Write-Host "  Demo.Api:  http://localhost:5002/orders/{orderId}"
Write-Host "  Demo.Func: http://localhost:7073/api/enrich?orderId={orderId}"
Write-Host ""
Write-Host "Test the trace:" -ForegroundColor Cyan
Write-Host "  curl http://localhost:5001/demo"
Write-Host "  Invoke-RestMethod http://localhost:5001/demo"
Write-Host ""
Write-Host "Close the terminal windows to stop services." -ForegroundColor Yellow
