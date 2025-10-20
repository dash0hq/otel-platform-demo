#!/usr/bin/env bash

set -eo pipefail

# Source environment variables from .env file
if [ -f ".env" ]; then
    source .env
else
    echo "Error: .env file not found. Please copy .env.template to .env and configure your settings."
    exit 1
fi

echo "Creating Dash0 secrets..."
kubectl create secret generic dash0-secrets \
    --from-literal=dash0-authorization-token="$DASH0_AUTH_TOKEN" \
    --from-literal=dash0-grpc-hostname="$DASH0_ENDPOINT_OTLP_GRPC_HOSTNAME" \
    --from-literal=dash0-grpc-port="$DASH0_ENDPOINT_OTLP_GRPC_PORT" \
    --from-literal=dash0-dataset="$DASH0_DATASET" \
    --namespace=opentelemetry

echo "Secrets created successfully!"
