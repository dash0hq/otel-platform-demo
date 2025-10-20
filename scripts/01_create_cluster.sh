#!/usr/bin/env bash

set -eo pipefail

CLUSTER_NAME=${CLUSTER_NAME:-otel-platform-demo}

echo "Creating kind cluster: $CLUSTER_NAME"
kind create cluster --name=$CLUSTER_NAME --config ./cluster/kind/multi-node.yaml

echo "Creating opentelemetry namespace..."
kubectl create namespace opentelemetry

echo ""
echo "Note: Infrastructure images will be pulled from remote registries during deployment."
echo "This may take a few minutes on first run, but images will be cached for subsequent runs."
echo ""
echo "Cluster created successfully!"
