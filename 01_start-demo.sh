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

# Backstage reads ${...} references from its environment, so the values behind the
# mcpChat block in app-config.yaml have to be exported before `yarn start`.
if [ -f .env ]; then
    set -a
    # shellcheck disable=SC1091
    source .env
    set +a
fi
: "${DASH0_MCP_URL:=https://api.eu-west-1.aws.dash0.com/mcp}"
export DASH0_MCP_URL

# The chat talks to Backstage's own MCP actions endpoint over HTTP, so it needs a
# token even though both sides live in the same backend. Nothing outside this
# machine uses it, so generate a fresh one per run rather than storing a secret --
# set BACKSTAGE_MCP_TOKEN in .env only if you want a stable value.
: "${BACKSTAGE_MCP_TOKEN:=$(openssl rand -hex 32)}"
export BACKSTAGE_MCP_TOKEN

echo "======================================"
echo "Starting Demo Environment"
echo "======================================"
echo ""

for var in ANTHROPIC_API_KEY DASH0_MCP_TOKEN; do
    if [ -z "${!var:-}" ]; then
        echo "⚠️  $var is not set in .env -- the 'Ask Dash0' chat page will not work."
    fi
done

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

echo "  - Jaeger (port 16686)"
kubectl port-forward svc/jaeger 16686 >/dev/null 2>&1 &
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
echo "  - Jaeger:                 http://localhost:16686"
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
