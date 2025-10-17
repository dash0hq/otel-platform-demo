#!/usr/bin/env bash

set -eo pipefail

VERSION=${VERSION:-v1}
CLUSTER_NAME=${CLUSTER_NAME:-kubecon-na}

echo "Building Docker images..."
docker build -f ./services/frontend/Dockerfile -t frontend:$VERSION ./services/frontend
docker build -f ./services/todo-service/Dockerfile -t todo-service:$VERSION ./services/todo-service
docker build -f ./services/notification-service/Dockerfile -t notification-service:$VERSION ./services/notification-service

echo "Loading images into kind cluster..."
kind load docker-image --name $CLUSTER_NAME frontend:$VERSION
kind load docker-image --name $CLUSTER_NAME todo-service:$VERSION
kind load docker-image --name $CLUSTER_NAME notification-service:$VERSION

echo "Images built and loaded successfully!"
