#!/usr/bin/env bash

set -eo pipefail

# cert-manager backs the admission webhooks of several components in this demo:
#   - the RabbitMQ cluster operator (step 5, required since operator v2.22.0)
#   - the OpenTelemetry operator (step 7)
# Both steps call this script, so it must stay idempotent.

echo "Deploying cert-manager..."
helm repo add jetstack https://charts.jetstack.io --force-update
helm upgrade --install cert-manager jetstack/cert-manager \
    --namespace cert-manager --create-namespace \
    --set crds.enabled=true

echo "Waiting for cert-manager to be ready..."
for deployment in cert-manager cert-manager-webhook cert-manager-cainjector; do
    kubectl wait --for=condition=available --timeout=180s \
        "deployment/$deployment" -n cert-manager
done

echo "cert-manager deployed successfully!"
