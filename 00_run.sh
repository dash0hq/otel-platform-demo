#!/usr/bin/env bash

set -eo pipefail

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
SKIP_COMPLETED=false

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
  --skip-completed    Automatically skip already completed steps
  -h, --help          Show this help message

Examples:
  $0                       # Normal run
  $0 --skip-completed      # Only run incomplete steps

EOF
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-completed)
            SKIP_COMPLETED=true
            shift
            ;;
        -h|--help)
            show_usage
            ;;
        *)
            echo -e "${RED}Error: Unknown option $1${NC}"
            show_usage
            ;;
    esac
done

echo "======================================"
echo "OpenTelemetry Platform Engineering Demo - Setup"
echo "======================================"
echo ""

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo -e "${RED}Error: .env file not found.${NC}"
    echo "Please copy .env.template to .env and configure your Dash0 settings."
    echo ""
    echo "  cp .env.template .env"
    echo ""
    exit 1
fi

# Source environment variables
source .env

# Function to check if a resource exists
check_resource() {
    local resource_type=$1
    local resource_name=$2
    local namespace=$3

    if [ -n "$namespace" ]; then
        kubectl get "$resource_type" "$resource_name" -n "$namespace" &>/dev/null
    else
        kubectl get "$resource_type" "$resource_name" &>/dev/null
    fi
    return $?
}

# Function to check if a step is completed
is_step_completed() {
    local step_num=$1

    case $step_num in
        1)
            kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME:-otel-platform-demo}$"
            ;;
        2)
            check_resource secret dash0-secrets opentelemetry
            ;;
        3)
            docker image inspect "frontend:${VERSION:-v1}" &>/dev/null
            ;;
        4)
            check_resource deployment mysql-operator mysql-operator && \
            check_resource innodbcluster my-mysql default
            ;;
        5)
            check_resource statefulset rabbitmq default
            ;;
        6)
            check_resource deployment prometheus-server default
            ;;
        7)
            check_resource deployment opentelemetry-operator-controller-manager opentelemetry-operator-system
            ;;
        8)
            check_resource deployment frontend default
            ;;
        9)
            check_resource deployment perses default
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to execute a step
execute_step() {
    local step_num=$1
    local step_name=$2
    local step_script=$3

    # Check if step is completed and should be skipped
    if [ "$SKIP_COMPLETED" = true ]; then
        if is_step_completed "$step_num"; then
            echo -e "${GREEN}✓ Step $step_num/9: $step_name (already completed, skipping)${NC}"
            return 0
        fi
    fi

    echo -e "${BLUE}Step $step_num/9: $step_name...${NC}"
    if $step_script; then
        echo -e "${GREEN}✓ Step $step_num completed successfully${NC}"
        return 0
    else
        echo ""
        echo -e "${RED}✗ Step $step_num failed${NC}"
        echo ""
        echo -e "${YELLOW}To skip completed steps and continue, run:${NC}"
        echo -e "  ./00_run.sh --skip-completed"
        echo ""
        return 1
    fi
}

echo "Starting deployment with the following configuration:"
echo "  Cluster Name: ${CLUSTER_NAME:-otel-platform-demo}"
echo "  Version: ${VERSION:-v1}"
if [ "$SKIP_COMPLETED" = true ]; then
    echo "  Mode: Skipping completed steps"
fi
echo ""

# Execute steps
execute_step 1 "Creating Kind cluster" ./scripts/01_create_cluster.sh
echo ""

execute_step 2 "Setting up Dash0 secrets" ./scripts/02_setup_secrets.sh
echo ""

execute_step 3 "Building and loading application Docker images" ./scripts/03_build_images.sh
echo ""

execute_step 4 "Deploying MySQL database" ./scripts/04_deploy_database.sh
echo ""

execute_step 5 "Deploying RabbitMQ message broker" ./scripts/05_deploy_rabbitmq.sh
echo ""

execute_step 6 "Deploying observability stack (Prometheus, OpenSearch, Jaeger)" ./scripts/06_deploy_observability.sh
echo ""

execute_step 7 "Deploying OpenTelemetry operator and collector" ./scripts/07_deploy_otel_operator.sh
echo ""

execute_step 8 "Deploying application services" ./scripts/08_deploy_services.sh
echo ""

execute_step 9 "Deploying Perses dashboards" ./scripts/09_deploy_perses.sh
echo ""

echo ""
echo "======================================"
echo "Deployment Complete!"
echo "======================================"
echo ""
