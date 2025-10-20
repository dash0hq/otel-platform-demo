#!/usr/bin/env bash

set -eo pipefail

CLUSTER_NAME=${CLUSTER_NAME:-otel-platform-demo}

echo "Creating kind cluster: $CLUSTER_NAME"
kind create cluster --name=$CLUSTER_NAME --config ./cluster/kind/multi-node.yaml

echo "Creating opentelemetry namespace..."
kubectl create namespace opentelemetry
