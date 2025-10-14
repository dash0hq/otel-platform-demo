#!/usr/bin/env bash

set -eo pipefail

echo "Deploying applications..."
kubectl apply -f ./services/frontend/manifests/
kubectl apply -f ./services/todo-service/manifests/
kubectl apply -f ./services/notification-service/manifests/

echo "Services deployed successfully!"
