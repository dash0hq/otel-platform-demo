#!/usr/bin/env bash

set -eo pipefail

CLUSTER_NAME=${CLUSTER_NAME:-kubecon-na}

echo "Deleting kind cluster: $CLUSTER_NAME"
kind delete cluster --name=$CLUSTER_NAME

echo "Cluster deleted successfully!"
