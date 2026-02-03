# ============================================================================
# Azure Monitoring Audit - Multi-Subscription Scripts (PowerShell)
# ============================================================================
# Purpose: Efficiently audit monitoring configuration across all subscriptions
# Access Required: Reader role on target subscriptions
# Usage: .\multi-subscription-audit.ps1 [-OutputDir "audit-folder"]
# ============================================================================

param(
    [string]$OutputDir = "audit-$(Get-Date -Format 'yyyyMMdd-HHmmss')",
    [int]$ThrottleLimit = 5
)

$ErrorActionPreference = "Continue"

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $colors = @{
        "INFO" = "Cyan"
        "SUCCESS" = "Green"
        "WARNING" = "Yellow"
        "ERROR" = "Red"
    }
    Write-Host "[$Level] $Message" -ForegroundColor $colors[$Level]
}

# ============================================================================
# 1. SETUP AND GET SUBSCRIPTIONS (Scoped to specific subscriptions)
# ============================================================================

# Define the specific subscriptions to audit
# Update this list to add/remove subscriptions from the audit scope
$TargetSubscriptions = @(
    @{ id = "76cd0ab7-9ab0-412a-b927-cc10e3d656d3"; name = "Edv2 BR QA" }
    @{ id = "039c62ed-7e0c-4d56-bb3f-be23033758ce"; name = "EVASM NEU PRO" }
    @{ id = "98d67ae7-6840-4bbb-a9db-23f12702daec"; name = "EVASM NEU QA" }
    @{ id = "8300de04-726b-4119-8637-1920254b613b"; name = "EVASM WUS PRO (LATAM)" }
    @{ id = "4f9b5670-6e01-452b-9068-534c3e8b80fd"; name = "MAE LATAM PRO" }
    @{ id = "04669dbd-24c3-4cbe-a6a0-dbae82a9cb91"; name = "MAE NEU PRO" }
    @{ id = "658a3795-22d3-4ac1-a87c-70810b337754"; name = "MAE NEU QA" }
    @{ id = "2e3c305c-04a8-48f7-b8f7-e615c5bf8669"; name = "RecursosInternos-DevOps" }
    @{ id = "1d08dafe-eb6c-4aa7-b738-a851f0959ba7"; name = "RecursosInternos-DevOps QA" }
)

function Initialize-AuditDirectory {
    $dirs = @(
        $OutputDir,
        "$OutputDir\subscriptions",
        "$OutputDir\summary",
        "$OutputDir\raw-data"
    )
    foreach ($dir in $dirs) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    Write-Log "Created audit directory: $OutputDir" "SUCCESS"
}

function Get-AllSubscriptions {
    Write-Log "Using predefined list of $($TargetSubscriptions.Count) target subscriptions..."
    
    # Build subscription objects with tenant IDs
    $subscriptions = $TargetSubscriptions | ForEach-Object {
        $tenantId = try {
            (az account show --subscription $_.id --query "tenantId" -o tsv 2>$null)
        } catch { "unknown" }
        
        [PSCustomObject]@{
            name = $_.name
            id = $_.id
            tenantId = if ($tenantId) { $tenantId } else { "unknown" }
        }
    }
    
    $subscriptions | ConvertTo-Json -Depth 10 | Out-File "$OutputDir\subscriptions.json"
    
    # Create CSV
    $subscriptions | Export-Csv "$OutputDir\subscriptions.csv" -NoTypeInformation
    
    Write-Log "Configured $($subscriptions.Count) target subscriptions for audit" "SUCCESS"
    return $subscriptions
}

# ============================================================================
# 2. AUDIT SINGLE SUBSCRIPTION
# ============================================================================

function Invoke-SubscriptionAudit {
    param(
        [string]$SubscriptionId,
        [string]$SubscriptionName
    )
    
    $subDir = "$OutputDir\subscriptions\$SubscriptionId"
    New-Item -ItemType Directory -Path $subDir -Force | Out-Null
    
    Write-Host "  Auditing: $SubscriptionName" -ForegroundColor Gray
    
    # Set context
    az account set --subscription $SubscriptionId 2>$null
    
    # Collect data
    $collections = @{
        "all-resources" = "az resource list"
        "app-services" = "az webapp list"
        "function-apps" = "az functionapp list"
        "app-insights" = "az monitor app-insights component list"
        "log-analytics" = "az monitor log-analytics workspace list"
        "action-groups" = "az monitor action-group list"
        "metric-alerts" = "az monitor metrics alert list"
        "scheduled-query-alerts" = "az monitor scheduled-query list"
        "policy-assignments" = "az policy assignment list"
    }
    
    foreach ($item in $collections.GetEnumerator()) {
        try {
            $result = Invoke-Expression "$($item.Value) -o json 2>`$null"
            if ($result) {
                $result | Out-File "$subDir\$($item.Key).json"
            } else {
                "[]" | Out-File "$subDir\$($item.Key).json"
            }
        } catch {
            "[]" | Out-File "$subDir\$($item.Key).json"
        }
    }
    
    # Generate summary
    $summary = @{
        subscriptionId = $SubscriptionId
        subscriptionName = $SubscriptionName
        auditDate = (Get-Date -Format "o")
        resourceCounts = @{
            totalResources = (Get-Content "$subDir\all-resources.json" | ConvertFrom-Json).Count
            appServices = (Get-Content "$subDir\app-services.json" | ConvertFrom-Json).Count
            functionApps = (Get-Content "$subDir\function-apps.json" | ConvertFrom-Json).Count
            appInsights = (Get-Content "$subDir\app-insights.json" | ConvertFrom-Json).Count
            logAnalyticsWorkspaces = (Get-Content "$subDir\log-analytics.json" | ConvertFrom-Json).Count
            actionGroups = (Get-Content "$subDir\action-groups.json" | ConvertFrom-Json).Count
            metricAlerts = (Get-Content "$subDir\metric-alerts.json" | ConvertFrom-Json).Count
            scheduledQueryAlerts = (Get-Content "$subDir\scheduled-query-alerts.json" | ConvertFrom-Json).Count
        }
    }
    
    $summary | ConvertTo-Json -Depth 10 | Out-File "$subDir\summary.json"
    Write-Host "  ✓ Completed: $SubscriptionName" -ForegroundColor Green
}

# ============================================================================
# 3. AGGREGATE RESULTS
# ============================================================================

function Invoke-AggregateResults {
    Write-Log "Aggregating results across all subscriptions..."
    
    $allSummaries = @()
    Get-ChildItem "$OutputDir\subscriptions\*\summary.json" | ForEach-Object {
        $allSummaries += Get-Content $_.FullName | ConvertFrom-Json
    }
    
    $allSummaries | ConvertTo-Json -Depth 10 | Out-File "$OutputDir\summary\full-audit-summary.json"
    
    # Create CSV
    $csvData = $allSummaries | ForEach-Object {
        [PSCustomObject]@{
            SubscriptionId = $_.subscriptionId
            SubscriptionName = $_.subscriptionName
            TotalResources = $_.resourceCounts.totalResources
            AppServices = $_.resourceCounts.appServices
            FunctionApps = $_.resourceCounts.functionApps
            AppInsights = $_.resourceCounts.appInsights
            LAW = $_.resourceCounts.logAnalyticsWorkspaces
            ActionGroups = $_.resourceCounts.actionGroups
            MetricAlerts = $_.resourceCounts.metricAlerts
            QueryAlerts = $_.resourceCounts.scheduledQueryAlerts
        }
    }
    $csvData | Export-Csv "$OutputDir\summary\resource-counts.csv" -NoTypeInformation
    
    # Calculate totals
    $totals = @{
        auditDate = (Get-Date -Format "o")
        subscriptionCount = $allSummaries.Count
        totals = @{
            resources = ($allSummaries.resourceCounts.totalResources | Measure-Object -Sum).Sum
            appServices = ($allSummaries.resourceCounts.appServices | Measure-Object -Sum).Sum
            functionApps = ($allSummaries.resourceCounts.functionApps | Measure-Object -Sum).Sum
            appInsights = ($allSummaries.resourceCounts.appInsights | Measure-Object -Sum).Sum
            logAnalyticsWorkspaces = ($allSummaries.resourceCounts.logAnalyticsWorkspaces | Measure-Object -Sum).Sum
            totalAlerts = ($allSummaries.resourceCounts.metricAlerts | Measure-Object -Sum).Sum + 
                          ($allSummaries.resourceCounts.scheduledQueryAlerts | Measure-Object -Sum).Sum
        }
    }
    
    $totals | ConvertTo-Json -Depth 10 | Out-File "$OutputDir\summary\totals.json"
    
    Write-Log "Aggregation complete" "SUCCESS"
    return $totals
}

# ============================================================================
# 4. SPECIFIC CHECKS
# ============================================================================

function Find-ClassicAppInsights {
    Write-Log "Checking for Classic App Insights..."
    
    $results = @()
    Get-ChildItem "$OutputDir\subscriptions\*\app-insights.json" | ForEach-Object {
        $subId = $_.Directory.Name
        $subName = (Get-Content "$($_.Directory.FullName)\summary.json" | ConvertFrom-Json).subscriptionName
        $appInsights = Get-Content $_.FullName | ConvertFrom-Json
        
        $appInsights | Where-Object { $_.ingestionMode -ne "LogAnalytics" } | ForEach-Object {
            $results += [PSCustomObject]@{
                SubscriptionId = $subId
                SubscriptionName = $subName
                AppInsightsName = $_.name
                ResourceGroup = $_.resourceGroup
                IngestionMode = if ($_.ingestionMode) { $_.ingestionMode } else { "Classic" }
            }
        }
    }
    
    $results | Export-Csv "$OutputDir\summary\classic-app-insights.csv" -NoTypeInformation
    
    if ($results.Count -gt 0) {
        Write-Log "Found $($results.Count) Classic App Insights instances (need migration)" "WARNING"
    } else {
        Write-Log "No Classic App Insights found" "SUCCESS"
    }
}

function Find-MissingTags {
    Write-Log "Checking for resources missing required tags..."
    
    $requiredTags = @("env", "workload", "owner", "costCenter")
    
    foreach ($tag in $requiredTags) {
        $results = @()
        
        Get-ChildItem "$OutputDir\subscriptions\*\all-resources.json" | ForEach-Object {
            $subId = $_.Directory.Name
            $subName = (Get-Content "$($_.Directory.FullName)\summary.json" | ConvertFrom-Json).subscriptionName
            $resources = Get-Content $_.FullName | ConvertFrom-Json
            
            $resources | Where-Object { -not $_.tags.$tag } | ForEach-Object {
                $results += [PSCustomObject]@{
                    SubscriptionId = $subId
                    SubscriptionName = $subName
                    ResourceName = $_.name
                    ResourceType = $_.type
                    ResourceGroup = $_.resourceGroup
                }
            }
        }
        
        $results | Export-Csv "$OutputDir\summary\missing-tag-$tag.csv" -NoTypeInformation
        Write-Log "Resources missing '$tag' tag: $($results.Count)" "INFO"
    }
}

function Get-LAWRetention {
    Write-Log "Checking Log Analytics Workspace retention..."
    
    $results = @()
    Get-ChildItem "$OutputDir\subscriptions\*\log-analytics.json" | ForEach-Object {
        $subId = $_.Directory.Name
        $subName = (Get-Content "$($_.Directory.FullName)\summary.json" | ConvertFrom-Json).subscriptionName
        $workspaces = Get-Content $_.FullName | ConvertFrom-Json
        
        $workspaces | ForEach-Object {
            $results += [PSCustomObject]@{
                SubscriptionId = $subId
                SubscriptionName = $subName
                WorkspaceName = $_.name
                ResourceGroup = $_.resourceGroup
                RetentionDays = $_.retentionInDays
                Sku = $_.sku.name
            }
        }
    }
    
    $results | Export-Csv "$OutputDir\summary\law-retention.csv" -NoTypeInformation
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

function Start-FullAudit {
    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "Azure Monitoring Multi-Subscription Audit" -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host ""
    
    Initialize-AuditDirectory
    $subscriptions = Get-AllSubscriptions
    
    Write-Log "Starting audit of $($subscriptions.Count) subscriptions..."
    
    foreach ($sub in $subscriptions) {
        Invoke-SubscriptionAudit -SubscriptionId $sub.id -SubscriptionName $sub.name
    }
    
    $totals = Invoke-AggregateResults
    
    # Run specific checks
    Find-ClassicAppInsights
    Find-MissingTags
    Get-LAWRetention
    
    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Green
    Write-Log "Audit complete! Results saved to: $OutputDir" "SUCCESS"
    Write-Host "==============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Summary:" -ForegroundColor Cyan
    Write-Host "  Subscriptions: $($totals.subscriptionCount)"
    Write-Host "  Total Resources: $($totals.totals.resources)"
    Write-Host "  App Services: $($totals.totals.appServices)"
    Write-Host "  Application Insights: $($totals.totals.appInsights)"
    Write-Host "  Total Alerts: $($totals.totals.totalAlerts)"
    Write-Host ""
    Write-Host "Key files:" -ForegroundColor Cyan
    Write-Host "  - $OutputDir\summary\totals.json"
    Write-Host "  - $OutputDir\summary\resource-counts.csv"
    Write-Host "  - $OutputDir\summary\classic-app-insights.csv"
}

# Run
Start-FullAudit
