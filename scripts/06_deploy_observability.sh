#!/usr/bin/env bash

set -eo pipefail

echo "Deploying Jaeger..."
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts || true
# Chart version is pinned deliberately: the 4.x chart declares itself EXPERIMENTAL
# with breaking changes possible in minor versions, so it should be bumped on
# purpose rather than drifting mid-demo.
JAEGER_EXISTED=false
kubectl get deployment jaeger >/dev/null 2>&1 && JAEGER_EXISTED=true
helm upgrade --install jaeger jaegertracing/jaeger --version 4.12.0 --values ./infrastructure/jaeger/values.yaml

# Jaeger v2's config lives in a ConfigMap, and the chart puts no checksum annotation
# on the pod template -- so editing infrastructure/jaeger/values.yaml updates the
# ConfigMap while the running pod keeps the previous config, silently. Restart when
# the Deployment already existed; a first install already starts with the new config.
if [ "$JAEGER_EXISTED" = true ]; then
    echo "Restarting Jaeger to pick up config changes..."
    kubectl rollout restart deployment/jaeger
fi
kubectl rollout status deployment/jaeger --timeout=240s

echo "Deploying Prometheus..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm upgrade --install prometheus prometheus-community/prometheus --values ./infrastructure/prometheus/values.yaml

echo "Deploying OpenSearch..."
helm repo add opensearch https://opensearch-project.github.io/helm-charts || true
helm upgrade --install opensearch opensearch/opensearch -f ./infrastructure/opensearch/values.yaml
helm upgrade --install opensearch-dashboards opensearch/opensearch-dashboards -f ./infrastructure/opensearch/dashboard-values.yaml

echo "Observability stack deployed successfully!"
