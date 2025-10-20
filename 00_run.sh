#!/usr/bin/env bash

set -eo pipefail

echo "======================================"
echo "OpenTelemetry Platform Engineering Demo - Setup"
echo "======================================"
echo ""

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "Error: .env file not found."
    echo "Please copy .env.template to .env and configure your Dash0 settings."
    echo ""
    echo "  cp .env.template .env"
    echo ""
    exit 1
fi

# Source environment variables
source .env

echo "Starting deployment with the following configuration:"
echo "  Cluster Name: ${CLUSTER_NAME:-otel-platform-demo}"
echo "  Version: ${VERSION:-v1}"
echo ""

# Step 1: Create cluster
echo "Step 1/9: Creating Kind cluster..."
./scripts/01_create_cluster.sh
echo ""

# Step 2: Setup secrets
echo "Step 2/9: Setting up Dash0 secrets..."
./scripts/02_setup_secrets.sh
echo ""

# Step 3: Build and load images
echo "Step 3/9: Building and loading application Docker images..."
./scripts/03_build_images.sh
echo ""

# Step 4: Deploy database
echo "Step 4/9: Deploying MySQL database..."
./scripts/04_deploy_database.sh
echo ""

# Step 5: Deploy RabbitMQ
echo "Step 5/9: Deploying RabbitMQ message broker..."
./scripts/05_deploy_rabbitmq.sh
echo ""

# Step 6: Deploy observability stack
echo "Step 6/9: Deploying observability stack (Prometheus, OpenSearch, Jaeger)..."
./scripts/06_deploy_observability.sh
echo ""

# Step 7: Deploy OpenTelemetry operator and collector
echo "Step 7/9: Deploying OpenTelemetry operator and collector..."
./scripts/07_deploy_otel_operator.sh
echo ""

# Step 8: Deploy services
echo "Step 8/9: Deploying application services..."
./scripts/08_deploy_services.sh
echo ""

# Step 9: Deploy Perses
echo "Step 9/9: Deploying Perses dashboards..."
./scripts/09_deploy_perses.sh
echo ""

echo "======================================"
echo "Deployment Complete!"
echo "======================================"
echo ""
