#!/usr/bin/env bash

set -eo pipefail

echo "Deploying cert-manager..."
helm repo add jetstack https://charts.jetstack.io --force-update
helm upgrade --install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --set crds.enabled=true

echo "Deploying OpenTelemetry Operator..."
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm upgrade --install opentelemetry-operator open-telemetry/opentelemetry-operator \
    --set "manager.collectorImage.repository=otel/opentelemetry-collector-k8s" \
    --namespace opentelemetry --create-namespace

echo "Deploying OpenTelemetry Collector (Deployment)..."
helm upgrade --install otel-collector-deployment open-telemetry/opentelemetry-collector \
    --namespace opentelemetry -f ./infrastructure/collector/deployment-values.yaml

echo "Deploying OpenTelemetry Collector (DaemonSet)..."
helm upgrade --install otel-collector-daemonset open-telemetry/opentelemetry-collector \
    --namespace opentelemetry -f ./infrastructure/collector/daemonset-values.yaml

echo "Waiting for OpenTelemetry operator to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/opentelemetry-operator -n opentelemetry

echo "Waiting for webhook to be ready..."
kubectl wait --for=condition=ready --timeout=300s pod -l app.kubernetes.io/name=opentelemetry-operator -n opentelemetry
sleep 30

echo "Applying instrumentation..."
kubectl apply -f ./infrastructure/instrumentations/instrumentation.yaml

echo "OpenTelemetry operator and collector deployed successfully!"
