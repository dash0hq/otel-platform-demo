#!/usr/bin/env bash

set -eo pipefail

echo "Deploying Jaeger..."
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts || true
helm upgrade --install jaeger jaegertracing/jaeger --version 3.4.1 --values ./infrastructure/jaeger/values.yaml

echo "Deploying Prometheus..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm upgrade --install prometheus prometheus-community/prometheus --values ./infrastructure/prometheus/values.yaml

echo "Deploying OpenSearch..."
helm repo add opensearch https://opensearch-project.github.io/helm-charts || true
helm upgrade --install opensearch opensearch/opensearch -f ./infrastructure/opensearch/values.yaml
helm upgrade --install opensearch-dashboards opensearch/opensearch-dashboards -f ./infrastructure/opensearch/dashboard-values.yaml

echo "Observability stack deployed successfully!"
