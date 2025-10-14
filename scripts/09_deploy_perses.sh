#!/usr/bin/env bash

set -eo pipefail

echo "Installing Perses Operator CRDs and deploying the operator..."
kustomize build 'github.com/perses/perses-operator/config/default?ref=a324bdf0142c98271cfa5a17e91ae4eaf461bbe8' | kubectl apply -f -

echo "Waiting for Perses operator to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/perses-operator-controller-manager -n perses-operator-system

echo "Deploying Perses instance..."
kubectl apply -f ./infrastructure/perses/perses.yaml

echo "Waiting for Perses to be ready..."
sleep 10
kubectl wait --for=condition=ready --timeout=300s pod -l app.kubernetes.io/name=perses -n default

echo "Deploying Prometheus datasource..."
kubectl apply -f ./infrastructure/perses/prometheus-datasource.yaml

echo "Perses deployed successfully!"
echo "Access Perses at: kubectl port-forward -n default svc/perses 8080:8080"
echo ""
echo "Note: Application dashboards will be deployed separately during the demo."
