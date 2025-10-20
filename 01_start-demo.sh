#!/usr/bin/env bash

set -eo pipefail

# Array to store background process PIDs
PIDS=()

# Cleanup function to kill all port-forwards
cleanup() {
    echo ""
    echo "======================================"
    echo "Stopping all port-forwards..."
    echo "======================================"

    for pid in "${PIDS[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
        fi
    done

    # Also kill any remaining kubectl port-forward processes
    pkill -f "kubectl port-forward" 2>/dev/null || true

    echo "Cleanup complete!"
}

# Register cleanup function to run on script exit
trap cleanup EXIT INT TERM

echo "======================================"
echo "Starting Demo Environment"
echo "======================================"
echo ""

# Start all port-forwards in the background
echo "Starting port-forwards..."

echo "  - OpenSearch Dashboards (port 5601)"
kubectl port-forward svc/opensearch-dashboards 5601 >/dev/null 2>&1 &
PIDS+=($!)

echo "  - Prometheus (port 9090)"
kubectl port-forward svc/prometheus 9090 >/dev/null 2>&1 &
PIDS+=($!)

echo "  - Perses (port 8000 -> 8080)"
kubectl port-forward svc/perses 8000:8080 >/dev/null 2>&1 &
PIDS+=($!)

echo "  - Jaeger Query (port 16686)"
kubectl port-forward svc/jaeger-query 16686 >/dev/null 2>&1 &
PIDS+=($!)

echo "  - Frontend (port 3001 -> 80)"
kubectl port-forward svc/frontend 3001:80 >/dev/null 2>&1 &
PIDS+=($!)

echo ""
echo "Port-forwards started successfully!"
echo ""
echo "Available services:"
echo "  - OpenSearch Dashboards: http://localhost:5601"
echo "  - Prometheus:             http://localhost:9090"
echo "  - Perses:                 http://localhost:8000"
echo "  - Jaeger Query:           http://localhost:16686"
echo "  - Frontend:               http://localhost:3001"
echo ""

# Give port-forwards a moment to establish
sleep 2

# Start Backstage
echo "======================================"
echo "Starting Backstage"
echo "======================================"
echo ""

# Check if we're in the right directory
if [ ! -d "backstage" ]; then
    echo "Error: backstage directory not found."
    echo "Please run this script from the project root directory."
    exit 1
fi

cd backstage

echo "Installing dependencies..."
yarn install

echo ""
echo "Starting Backstage..."
echo "Backstage will be available at: http://localhost:3000"
echo "Backend API will be available at: http://localhost:7007"
echo ""

yarn start
