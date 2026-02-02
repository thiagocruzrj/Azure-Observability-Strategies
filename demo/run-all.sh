#!/bin/bash
# ============================================================================
# Run All Services Script (Linux/macOS)
# ============================================================================
# This script starts all three services in the background and waits for them.
# Press Ctrl+C to stop all services.
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "============================================"
echo "Distributed Tracing Demo - Starting Services"
echo "============================================"
echo ""

# Check for required tools
if ! command -v dotnet &> /dev/null; then
    echo "ERROR: .NET SDK not found. Please install .NET 8 SDK."
    exit 1
fi

if ! command -v func &> /dev/null; then
    echo "ERROR: Azure Functions Core Tools not found."
    echo "Install with: npm install -g azure-functions-core-tools@4"
    exit 1
fi

# Build all projects first
echo "[1/4] Building projects..."
dotnet build "$SCRIPT_DIR/DistributedTracingDemo.sln" --configuration Debug --verbosity minimal

echo ""
echo "[2/4] Starting Demo.Func on port 7073..."
cd "$SCRIPT_DIR/Demo.Func"
func start --port 7073 &
FUNC_PID=$!

# Wait for Functions to start
sleep 5

echo ""
echo "[3/4] Starting Demo.Api on port 5002..."
cd "$SCRIPT_DIR/Demo.Api"
dotnet run --no-build --urls "http://localhost:5002" &
API_PID=$!

# Wait for API to start
sleep 3

echo ""
echo "[4/4] Starting Demo.Web on port 5001..."
cd "$SCRIPT_DIR/Demo.Web"
dotnet run --no-build --urls "http://localhost:5001" &
WEB_PID=$!

# Wait for Web to start
sleep 3

echo ""
echo "============================================"
echo "All services started!"
echo "============================================"
echo ""
echo "Endpoints:"
echo "  Demo.Web:  http://localhost:5001/demo"
echo "  Demo.Api:  http://localhost:5002/orders/{orderId}"
echo "  Demo.Func: http://localhost:7073/api/enrich?orderId={orderId}"
echo ""
echo "Test the trace:"
echo "  curl http://localhost:5001/demo"
echo ""
echo "Press Ctrl+C to stop all services..."
echo ""

# Trap Ctrl+C to clean up
cleanup() {
    echo ""
    echo "Stopping services..."
    kill $FUNC_PID $API_PID $WEB_PID 2>/dev/null
    wait
    echo "All services stopped."
}

trap cleanup INT TERM

# Wait for all background processes
wait
