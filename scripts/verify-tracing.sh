#!/bin/bash
# ============================================================================
# Trace Correlation Verification Script
# Run this after deployment to verify distributed tracing is working
# ============================================================================
# Usage: ./scripts/verify-tracing.sh
# ============================================================================

set -e

# Configuration
RG="rg-obs-demo-dev-weu"
WEB_URL="https://web-obs-demo-dev-weu.azurewebsites.net"
LAW_NAME="law-obs-demo-dev-weu"
WAIT_SECONDS=30

echo "=============================================="
echo "  Distributed Tracing Verification Script"
echo "=============================================="
echo ""

# Step 1: Generate test traffic
echo "=== Step 1: Generate Test Traffic ==="
RESPONSE=$(curl -s "$WEB_URL/demo")
TRACE_ID=$(echo $RESPONSE | grep -oP '"traceId":"[^"]+' | cut -d'"' -f4)

if [ -z "$TRACE_ID" ]; then
    echo "ERROR: Could not extract traceId from response"
    echo "Response: $RESPONSE"
    exit 1
fi

echo "TraceId: $TRACE_ID"
echo "Response: $RESPONSE"
echo ""

# Step 2: Wait for telemetry ingestion
echo "=== Step 2: Wait for telemetry ingestion (${WAIT_SECONDS}s) ==="
echo "App Insights has ~30s delay for data to appear in LAW..."
sleep $WAIT_SECONDS
echo "Done waiting."
echo ""

# Step 3: Get LAW workspace ID
echo "=== Step 3: Get LAW Workspace ID ==="
LAW_ID=$(az monitor log-analytics workspace show \
  --workspace-name $LAW_NAME \
  --resource-group $RG \
  --query customerId -o tsv)
echo "LAW ID: $LAW_ID"
echo ""

# Step 4: Query end-to-end trace
echo "=== Step 4: Query End-to-End Trace ==="
echo "Looking for OperationId: $TRACE_ID"
echo ""

az monitor log-analytics query \
  --workspace $LAW_ID \
  --analytics-query "union AppRequests, AppDependencies | where TimeGenerated > ago(5m) | where OperationId == '$TRACE_ID' | project TimeGenerated, Type, Name, AppRoleName, Success | order by TimeGenerated asc" \
  -o table

echo ""

# Step 5: Verify dependencies
echo "=== Step 5: Verify Service Dependencies ==="
az monitor log-analytics query \
  --workspace $LAW_ID \
  --analytics-query "AppDependencies | where TimeGenerated > ago(5m) | where OperationId == '$TRACE_ID' | summarize count() by AppRoleName, Target, Success" \
  -o table

echo ""

# Step 6: Summary
echo "=============================================="
echo "  Verification Summary"
echo "=============================================="
echo ""
echo "TraceId: $TRACE_ID"
echo ""
echo "Expected trace flow:"
echo "  1. Demo.Web    → GET /demo           (AppRequests)"
echo "  2. Demo.Web    → api-obs-*           (AppDependencies)"
echo "  3. Demo.Api    → GET /orders/{id}    (AppRequests)"
echo "  4. Demo.Api    → func-obs-*          (AppDependencies)"
echo "  5. Demo.Func   → GET /api/enrich     (AppRequests)"
echo ""
echo "If you see all 5 steps above, distributed tracing is working!"
echo ""
echo "Application Map URL:"
SUB_ID=$(az account show --query id -o tsv)
echo "https://portal.azure.com/#@/resource/subscriptions/$SUB_ID/resourceGroups/$RG/providers/microsoft.insights/components/appi-web-demo-dev-weu/applicationMap"
echo ""
echo "=============================================="
