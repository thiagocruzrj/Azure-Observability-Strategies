#!/bin/bash
# ============================================================================
# Azure Monitoring Audit - Multi-Subscription Scripts
# ============================================================================
# Purpose: Efficiently audit monitoring configuration across all subscriptions
# Access Required: Reader role on target subscriptions
# Usage: ./multi-subscription-audit.sh [output-dir]
# ============================================================================

set -e

# Configuration
AUDIT_DIR="${1:-audit-$(date +%Y%m%d-%H%M%S)}"
PARALLEL_JOBS=5  # Adjust based on Azure API rate limits

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Create output directory structure
setup_output_dir() {
    mkdir -p "$AUDIT_DIR"/{subscriptions,summary,raw-data}
    log_info "Created audit directory: $AUDIT_DIR"
}

# ============================================================================
# 1. GET TARGET SUBSCRIPTIONS (Scoped to specific subscriptions)
# ============================================================================

# Define the specific subscriptions to audit
# Update this list to add/remove subscriptions from the audit scope
TARGET_SUBSCRIPTIONS=(
    "76cd0ab7-9ab0-412a-b927-cc10e3d656d3|Edv2 BR QA"
    "039c62ed-7e0c-4d56-bb3f-be23033758ce|EVASM NEU PRO"
    "98d67ae7-6840-4bbb-a9db-23f12702daec|EVASM NEU QA"
    "8300de04-726b-4119-8637-1920254b613b|EVASM WUS PRO (LATAM)"
    "4f9b5670-6e01-452b-9068-534c3e8b80fd|MAE LATAM PRO"
    "04669dbd-24c3-4cbe-a6a0-dbae82a9cb91|MAE NEU PRO"
    "658a3795-22d3-4ac1-a87c-70810b337754|MAE NEU QA"
    "2e3c305c-04a8-48f7-b8f7-e615c5bf8669|RecursosInternos-DevOps"
    "1d08dafe-eb6c-4aa7-b738-a851f0959ba7|RecursosInternos-DevOps QA"
)

get_all_subscriptions() {
    log_info "Using predefined list of ${#TARGET_SUBSCRIPTIONS[@]} target subscriptions..."
    
    # Build JSON array from the target subscriptions
    echo "[" > "$AUDIT_DIR/subscriptions.json"
    first=true
    for sub in "${TARGET_SUBSCRIPTIONS[@]}"; do
        IFS='|' read -r sub_id sub_name <<< "$sub"
        if [ "$first" = true ]; then
            first=false
        else
            echo "," >> "$AUDIT_DIR/subscriptions.json"
        fi
        # Get tenant ID from Azure (or use placeholder if not accessible)
        tenant_id=$(az account show --subscription "$sub_id" --query "tenantId" -o tsv 2>/dev/null || echo "unknown")
        echo "  {\"name\": \"$sub_name\", \"id\": \"$sub_id\", \"tenantId\": \"$tenant_id\"}" >> "$AUDIT_DIR/subscriptions.json"
    done
    echo "]" >> "$AUDIT_DIR/subscriptions.json"
    
    SUBSCRIPTION_COUNT=$(jq length "$AUDIT_DIR/subscriptions.json")
    log_success "Configured $SUBSCRIPTION_COUNT target subscriptions for audit"
    
    # Create CSV for easy viewing
    echo "SubscriptionName,SubscriptionId,TenantId" > "$AUDIT_DIR/subscriptions.csv"
    jq -r '.[] | "\(.name),\(.id),\(.tenantId)"' "$AUDIT_DIR/subscriptions.json" >> "$AUDIT_DIR/subscriptions.csv"
}

# ============================================================================
# 2. AUDIT SINGLE SUBSCRIPTION (called in parallel)
# ============================================================================

audit_subscription() {
    local SUB_ID="$1"
    local SUB_NAME="$2"
    # Strip any carriage returns from Windows line endings
    SUB_ID=$(echo "$SUB_ID" | tr -d '\r')
    SUB_NAME=$(echo "$SUB_NAME" | tr -d '\r')
    local OUTPUT_DIR="$AUDIT_DIR/subscriptions/$SUB_ID"
    
    mkdir -p "$OUTPUT_DIR"
    
    echo "Auditing: $SUB_NAME ($SUB_ID)"
    
    # Set subscription context
    az account set --subscription "$SUB_ID" 2>/dev/null
    
    # --- Resource Inventory ---
    az resource list -o json > "$OUTPUT_DIR/all-resources.json" 2>/dev/null || echo "[]" > "$OUTPUT_DIR/all-resources.json"
    
    # --- App Services ---
    az webapp list -o json > "$OUTPUT_DIR/app-services.json" 2>/dev/null || echo "[]" > "$OUTPUT_DIR/app-services.json"
    
    # --- Function Apps ---
    az functionapp list -o json > "$OUTPUT_DIR/function-apps.json" 2>/dev/null || echo "[]" > "$OUTPUT_DIR/function-apps.json"
    
    # --- Application Insights ---
    az monitor app-insights component list -o json > "$OUTPUT_DIR/app-insights.json" 2>/dev/null || echo "[]" > "$OUTPUT_DIR/app-insights.json"
    
    # --- Log Analytics Workspaces ---
    az monitor log-analytics workspace list -o json > "$OUTPUT_DIR/log-analytics.json" 2>/dev/null || echo "[]" > "$OUTPUT_DIR/log-analytics.json"
    
    # --- Action Groups ---
    az monitor action-group list -o json > "$OUTPUT_DIR/action-groups.json" 2>/dev/null || echo "[]" > "$OUTPUT_DIR/action-groups.json"
    
    # --- Alert Rules ---
    az monitor metrics alert list -o json > "$OUTPUT_DIR/metric-alerts.json" 2>/dev/null || echo "[]" > "$OUTPUT_DIR/metric-alerts.json"
    az monitor scheduled-query list -o json > "$OUTPUT_DIR/scheduled-query-alerts.json" 2>/dev/null || echo "[]" > "$OUTPUT_DIR/scheduled-query-alerts.json"
    
    # --- Policy Assignments ---
    az policy assignment list -o json > "$OUTPUT_DIR/policy-assignments.json" 2>/dev/null || echo "[]" > "$OUTPUT_DIR/policy-assignments.json"
    
    # --- Generate subscription summary ---
    cat > "$OUTPUT_DIR/summary.json" << EOF
{
    "subscriptionId": "$SUB_ID",
    "subscriptionName": "$SUB_NAME",
    "auditDate": "$(date -Iseconds)",
    "resourceCounts": {
        "totalResources": $(jq length "$OUTPUT_DIR/all-resources.json"),
        "appServices": $(jq length "$OUTPUT_DIR/app-services.json"),
        "functionApps": $(jq length "$OUTPUT_DIR/function-apps.json"),
        "appInsights": $(jq length "$OUTPUT_DIR/app-insights.json"),
        "logAnalyticsWorkspaces": $(jq length "$OUTPUT_DIR/log-analytics.json"),
        "actionGroups": $(jq length "$OUTPUT_DIR/action-groups.json"),
        "metricAlerts": $(jq length "$OUTPUT_DIR/metric-alerts.json"),
        "scheduledQueryAlerts": $(jq length "$OUTPUT_DIR/scheduled-query-alerts.json")
    }
}
EOF
    
    echo "✓ Completed: $SUB_NAME"
}

# ============================================================================
# 3. RUN AUDIT ACROSS ALL SUBSCRIPTIONS
# ============================================================================

run_full_audit() {
    log_info "Starting full multi-subscription audit..."
    
    # Read subscriptions and audit each
    jq -r '.[] | "\(.id)|\(.name)"' "$AUDIT_DIR/subscriptions.json" | while IFS='|' read -r sub_id sub_name; do
        audit_subscription "$sub_id" "$sub_name"
    done
    
    log_success "Completed auditing all subscriptions"
}

# Parallel version (faster but be careful with API limits)
run_full_audit_parallel() {
    log_info "Starting parallel multi-subscription audit (max $PARALLEL_JOBS concurrent)..."
    
    # Export function for parallel execution
    export -f audit_subscription
    export AUDIT_DIR
    
    jq -r '.[] | "\(.id)|\(.name)"' "$AUDIT_DIR/subscriptions.json" | \
        xargs -P $PARALLEL_JOBS -I {} bash -c 'IFS="|" read -r sub_id sub_name <<< "{}"; audit_subscription "$sub_id" "$sub_name"'
    
    log_success "Completed parallel audit of all subscriptions"
}

# ============================================================================
# 4. AGGREGATE RESULTS
# ============================================================================

aggregate_results() {
    log_info "Aggregating results across all subscriptions..."
    
    local SUMMARY_FILE="$AUDIT_DIR/summary/full-audit-summary.json"
    local CSV_FILE="$AUDIT_DIR/summary/resource-counts.csv"
    
    # Aggregate all subscription summaries
    echo "[" > "$SUMMARY_FILE"
    first=true
    for summary in "$AUDIT_DIR"/subscriptions/*/summary.json; do
        if [ -f "$summary" ]; then
            if [ "$first" = true ]; then
                first=false
            else
                echo "," >> "$SUMMARY_FILE"
            fi
            cat "$summary" >> "$SUMMARY_FILE"
        fi
    done
    echo "]" >> "$SUMMARY_FILE"
    
    # Create CSV summary
    echo "SubscriptionId,SubscriptionName,TotalResources,AppServices,FunctionApps,AppInsights,LAW,ActionGroups,MetricAlerts,QueryAlerts" > "$CSV_FILE"
    
    jq -r '.[] | "\(.subscriptionId),\(.subscriptionName),\(.resourceCounts.totalResources),\(.resourceCounts.appServices),\(.resourceCounts.functionApps),\(.resourceCounts.appInsights),\(.resourceCounts.logAnalyticsWorkspaces),\(.resourceCounts.actionGroups),\(.resourceCounts.metricAlerts),\(.resourceCounts.scheduledQueryAlerts)"' "$SUMMARY_FILE" >> "$CSV_FILE"
    
    # Calculate totals
    local TOTAL_RESOURCES=$(jq '[.[].resourceCounts.totalResources] | add' "$SUMMARY_FILE")
    local TOTAL_APPS=$(jq '[.[].resourceCounts.appServices] | add' "$SUMMARY_FILE")
    local TOTAL_FUNCS=$(jq '[.[].resourceCounts.functionApps] | add' "$SUMMARY_FILE")
    local TOTAL_APPI=$(jq '[.[].resourceCounts.appInsights] | add' "$SUMMARY_FILE")
    local TOTAL_LAW=$(jq '[.[].resourceCounts.logAnalyticsWorkspaces] | add' "$SUMMARY_FILE")
    local TOTAL_ALERTS=$(jq '[.[].resourceCounts.metricAlerts + .[].resourceCounts.scheduledQueryAlerts] | add' "$SUMMARY_FILE")
    
    cat > "$AUDIT_DIR/summary/totals.json" << EOF
{
    "auditDate": "$(date -Iseconds)",
    "subscriptionCount": $(jq length "$SUMMARY_FILE"),
    "totals": {
        "resources": $TOTAL_RESOURCES,
        "appServices": $TOTAL_APPS,
        "functionApps": $TOTAL_FUNCS,
        "appInsights": $TOTAL_APPI,
        "logAnalyticsWorkspaces": $TOTAL_LAW,
        "totalAlerts": $TOTAL_ALERTS
    }
}
EOF
    
    log_success "Aggregation complete. Summary saved to $AUDIT_DIR/summary/"
}

# ============================================================================
# 5. SPECIFIC MULTI-SUBSCRIPTION CHECKS
# ============================================================================

# Check for Classic App Insights across all subscriptions
check_classic_app_insights() {
    log_info "Checking for Classic (non-workspace) App Insights..."
    
    local OUTPUT="$AUDIT_DIR/summary/classic-app-insights.csv"
    echo "SubscriptionId,SubscriptionName,AppInsightsName,ResourceGroup,IngestionMode" > "$OUTPUT"
    
    jq -r '.[] | "\(.id)|\(.name)"' "$AUDIT_DIR/subscriptions.json" | while IFS='|' read -r sub_id sub_name; do
        local APPI_FILE="$AUDIT_DIR/subscriptions/$sub_id/app-insights.json"
        if [ -f "$APPI_FILE" ]; then
            jq -r --arg subid "$sub_id" --arg subname "$sub_name" \
                '.[] | select(.ingestionMode != "LogAnalytics") | "\($subid),\($subname),\(.name),\(.resourceGroup),\(.ingestionMode // "Classic")"' \
                "$APPI_FILE" >> "$OUTPUT"
        fi
    done
    
    local COUNT=$(tail -n +2 "$OUTPUT" | wc -l)
    if [ "$COUNT" -gt 0 ]; then
        log_warning "Found $COUNT Classic App Insights instances (need migration)"
    else
        log_success "No Classic App Insights found"
    fi
}

# Check for resources missing required tags
check_missing_tags() {
    log_info "Checking for resources missing required tags..."
    
    local REQUIRED_TAGS=("env" "workload" "owner" "costCenter")
    
    for tag in "${REQUIRED_TAGS[@]}"; do
        local OUTPUT="$AUDIT_DIR/summary/missing-tag-$tag.csv"
        echo "SubscriptionId,SubscriptionName,ResourceName,ResourceType,ResourceGroup" > "$OUTPUT"
        
        jq -r '.[] | "\(.id)|\(.name)"' "$AUDIT_DIR/subscriptions.json" | while IFS='|' read -r sub_id sub_name; do
            local RES_FILE="$AUDIT_DIR/subscriptions/$sub_id/all-resources.json"
            if [ -f "$RES_FILE" ]; then
                jq -r --arg subid "$sub_id" --arg subname "$sub_name" --arg tag "$tag" \
                    '.[] | select(.tags[$tag] == null) | "\($subid),\($subname),\(.name),\(.type),\(.resourceGroup)"' \
                    "$RES_FILE" >> "$OUTPUT" 2>/dev/null || true
            fi
        done
        
        local COUNT=$(tail -n +2 "$OUTPUT" | wc -l)
        log_info "Resources missing '$tag' tag: $COUNT"
    done
}

# Check App Services without App Insights
check_apps_without_monitoring() {
    log_info "Checking for App Services without Application Insights..."
    
    local OUTPUT="$AUDIT_DIR/summary/apps-without-appi.csv"
    echo "SubscriptionId,SubscriptionName,AppServiceName,ResourceGroup" > "$OUTPUT"
    
    jq -r '.[] | "\(.id)|\(.name)"' "$AUDIT_DIR/subscriptions.json" | while IFS='|' read -r sub_id sub_name; do
        az account set --subscription "$sub_id" 2>/dev/null
        
        local APPS_FILE="$AUDIT_DIR/subscriptions/$sub_id/app-services.json"
        if [ -f "$APPS_FILE" ] && [ "$(jq length "$APPS_FILE")" -gt 0 ]; then
            jq -r '.[] | "\(.name)|\(.resourceGroup)"' "$APPS_FILE" | while IFS='|' read -r app_name app_rg; do
                # Check if app has APPLICATIONINSIGHTS_CONNECTION_STRING
                local HAS_APPI=$(az webapp config appsettings list -n "$app_name" -g "$app_rg" \
                    --query "[?name=='APPLICATIONINSIGHTS_CONNECTION_STRING'].value" -o tsv 2>/dev/null)
                
                if [ -z "$HAS_APPI" ]; then
                    echo "$sub_id,$sub_name,$app_name,$app_rg" >> "$OUTPUT"
                fi
            done
        fi
    done
    
    local COUNT=$(tail -n +2 "$OUTPUT" | wc -l)
    if [ "$COUNT" -gt 0 ]; then
        log_warning "Found $COUNT App Services without Application Insights"
    else
        log_success "All App Services have Application Insights configured"
    fi
}

# Check LAW retention across subscriptions
check_law_retention() {
    log_info "Checking Log Analytics Workspace retention settings..."
    
    local OUTPUT="$AUDIT_DIR/summary/law-retention.csv"
    echo "SubscriptionId,SubscriptionName,WorkspaceName,ResourceGroup,RetentionDays,Sku" > "$OUTPUT"
    
    jq -r '.[] | "\(.id)|\(.name)"' "$AUDIT_DIR/subscriptions.json" | while IFS='|' read -r sub_id sub_name; do
        local LAW_FILE="$AUDIT_DIR/subscriptions/$sub_id/log-analytics.json"
        if [ -f "$LAW_FILE" ]; then
            jq -r --arg subid "$sub_id" --arg subname "$sub_name" \
                '.[] | "\($subid),\($subname),\(.name),\(.resourceGroup),\(.retentionInDays),\(.sku.name)"' \
                "$LAW_FILE" >> "$OUTPUT"
        fi
    done
}

# Check alert coverage
check_alert_coverage() {
    log_info "Checking alert coverage across subscriptions..."
    
    local OUTPUT="$AUDIT_DIR/summary/alert-coverage.csv"
    echo "SubscriptionId,SubscriptionName,AppServices,FunctionApps,MetricAlerts,QueryAlerts,AlertRatio" > "$OUTPUT"
    
    jq -r '.[] | 
        "\(.subscriptionId),\(.subscriptionName),\(.resourceCounts.appServices),\(.resourceCounts.functionApps),\(.resourceCounts.metricAlerts),\(.resourceCounts.scheduledQueryAlerts)"' \
        "$AUDIT_DIR/summary/full-audit-summary.json" | while IFS=',' read -r sub_id sub_name apps funcs metric_alerts query_alerts; do
        
        # Clean values - remove any carriage returns
        apps=$(echo "$apps" | tr -d '\r')
        funcs=$(echo "$funcs" | tr -d '\r')
        metric_alerts=$(echo "$metric_alerts" | tr -d '\r')
        query_alerts=$(echo "$query_alerts" | tr -d '\r')
        
        # Default to 0 if empty
        apps=${apps:-0}
        funcs=${funcs:-0}
        metric_alerts=${metric_alerts:-0}
        query_alerts=${query_alerts:-0}
        
        local TOTAL_APPS=$((apps + funcs))
        local TOTAL_ALERTS=$((metric_alerts + query_alerts))
        local RATIO="N/A"
        
        if [ "$TOTAL_APPS" -gt 0 ]; then
            RATIO=$(echo "scale=2; $TOTAL_ALERTS / $TOTAL_APPS" | bc 2>/dev/null || echo "N/A")
        fi
        
        echo "$sub_id,$sub_name,$apps,$funcs,$metric_alerts,$query_alerts,$RATIO" >> "$OUTPUT"
    done
}

# ============================================================================
# 6. GENERATE CONSOLIDATED REPORT
# ============================================================================

generate_report() {
    log_info "Generating consolidated audit report..."
    
    local REPORT="$AUDIT_DIR/AUDIT-REPORT.md"
    local TOTALS=$(cat "$AUDIT_DIR/summary/totals.json")
    
    cat > "$REPORT" << 'HEADER'
# Azure Monitoring Audit Report

**Generated:** AUDIT_DATE
**Subscriptions Audited:** SUB_COUNT

---

## Executive Summary

### Resource Totals Across All Subscriptions

| Resource Type | Count |
|---------------|-------|
HEADER

    # Replace placeholders
    sed -i "s/AUDIT_DATE/$(date '+%Y-%m-%d %H:%M:%S')/g" "$REPORT"
    sed -i "s/SUB_COUNT/$(jq '.subscriptionCount' <<< "$TOTALS")/g" "$REPORT"
    
    # Add resource counts
    echo "| Total Resources | $(jq '.totals.resources' <<< "$TOTALS") |" >> "$REPORT"
    echo "| App Services | $(jq '.totals.appServices' <<< "$TOTALS") |" >> "$REPORT"
    echo "| Function Apps | $(jq '.totals.functionApps' <<< "$TOTALS") |" >> "$REPORT"
    echo "| Application Insights | $(jq '.totals.appInsights' <<< "$TOTALS") |" >> "$REPORT"
    echo "| Log Analytics Workspaces | $(jq '.totals.logAnalyticsWorkspaces' <<< "$TOTALS") |" >> "$REPORT"
    echo "| Total Alerts | $(jq '.totals.totalAlerts' <<< "$TOTALS") |" >> "$REPORT"
    
    cat >> "$REPORT" << 'FINDINGS'

---

## Key Findings

### 🔴 Critical Issues

FINDINGS

    # Add Classic App Insights count
    local CLASSIC_COUNT=$(tail -n +2 "$AUDIT_DIR/summary/classic-app-insights.csv" 2>/dev/null | wc -l)
    if [ "$CLASSIC_COUNT" -gt 0 ]; then
        echo "- **$CLASSIC_COUNT Classic App Insights instances** need migration to workspace-based" >> "$REPORT"
    fi
    
    # Add apps without monitoring
    local NO_APPI_COUNT=$(tail -n +2 "$AUDIT_DIR/summary/apps-without-appi.csv" 2>/dev/null | wc -l)
    if [ "$NO_APPI_COUNT" -gt 0 ]; then
        echo "- **$NO_APPI_COUNT App Services** without Application Insights" >> "$REPORT"
    fi
    
    cat >> "$REPORT" << 'DETAILS'

### 🟡 Warnings

See detailed CSV files in `summary/` folder for:
- `missing-tag-*.csv` - Resources missing required tags
- `classic-app-insights.csv` - App Insights needing migration
- `apps-without-appi.csv` - Unmonitored applications
- `law-retention.csv` - Workspace retention settings
- `alert-coverage.csv` - Alert-to-app ratios

---

## Per-Subscription Details

| Subscription | Resources | Apps | Functions | App Insights | LAW | Alerts |
|--------------|-----------|------|-----------|--------------|-----|--------|
DETAILS

    # Add per-subscription table
    jq -r '.[] | "| \(.subscriptionName) | \(.resourceCounts.totalResources) | \(.resourceCounts.appServices) | \(.resourceCounts.functionApps) | \(.resourceCounts.appInsights) | \(.resourceCounts.logAnalyticsWorkspaces) | \(.resourceCounts.metricAlerts + .resourceCounts.scheduledQueryAlerts) |"' \
        "$AUDIT_DIR/summary/full-audit-summary.json" >> "$REPORT"
    
    cat >> "$REPORT" << 'FOOTER'

---

## Detailed Data Files

All raw data is available in the `subscriptions/` folder, organized by subscription ID.

### Summary Files

- `summary/full-audit-summary.json` - Complete audit data
- `summary/totals.json` - Aggregated totals
- `summary/resource-counts.csv` - Resource counts per subscription
- `summary/classic-app-insights.csv` - Classic App Insights needing migration
- `summary/apps-without-appi.csv` - Apps without monitoring
- `summary/missing-tag-*.csv` - Tag compliance issues
- `summary/law-retention.csv` - LAW retention settings
- `summary/alert-coverage.csv` - Alert coverage analysis

---

*Generated by Azure Monitoring Audit Script*
FOOTER

    log_success "Report generated: $REPORT"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    echo "=============================================="
    echo "Azure Monitoring Multi-Subscription Audit"
    echo "=============================================="
    echo ""
    
    setup_output_dir
    get_all_subscriptions
    run_full_audit  # Use run_full_audit_parallel for faster execution
    aggregate_results
    
    # Run specific checks
    check_classic_app_insights
    check_missing_tags
    check_law_retention
    check_alert_coverage
    # check_apps_without_monitoring  # Uncomment if needed (slow - makes API calls)
    
    generate_report
    
    echo ""
    echo "=============================================="
    log_success "Audit complete! Results saved to: $AUDIT_DIR"
    echo "=============================================="
    echo ""
    echo "Key files:"
    echo "  - $AUDIT_DIR/AUDIT-REPORT.md"
    echo "  - $AUDIT_DIR/summary/totals.json"
    echo "  - $AUDIT_DIR/summary/resource-counts.csv"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
