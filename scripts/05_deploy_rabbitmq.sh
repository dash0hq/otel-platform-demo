#!/usr/bin/env bash

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Deploying RabbitMQ..."

# Since v2.22.0 the cluster operator manifest ships cert-manager Certificate and
# Issuer resources for its admission webhooks, and the operator Deployment mounts
# the resulting secret. Without cert-manager the apply fails and the operator pod
# never leaves ContainerCreating.
"$SCRIPT_DIR/deploy_cert_manager.sh"

echo "Installing RabbitMQ Cluster Operator..."
OPERATOR_URL="https://github.com/rabbitmq/cluster-operator/releases/latest/download/cluster-operator.yml"
OPERATOR_MANIFEST="$(mktemp -t cluster-operator.XXXXXX)"
trap 'rm -f "$OPERATOR_MANIFEST"' EXIT

for attempt in 1 2 3; do
    echo "Download attempt $attempt/3..."
    if curl -fsSL -o "$OPERATOR_MANIFEST" "$OPERATOR_URL"; then
        break
    fi
    if [ "$attempt" -eq 3 ]; then
        echo "❌ Failed to download RabbitMQ operator manifest after 3 attempts"
        echo "   URL: $OPERATOR_URL"
        exit 1
    fi
    echo "⚠️  Download failed, retrying in 5 seconds..."
    sleep 5
done

# Retried separately from the download: cert-manager's webhook can still reject
# the Certificate resources for a few seconds after it reports available.
for attempt in 1 2 3; do
    echo "Apply attempt $attempt/3..."
    if kubectl apply -f "$OPERATOR_MANIFEST"; then
        echo "✓ Successfully installed RabbitMQ operator"
        break
    fi
    if [ "$attempt" -eq 3 ]; then
        echo "❌ Failed to apply RabbitMQ operator manifest after 3 attempts"
        exit 1
    fi
    echo "⚠️  Apply failed, retrying in 10 seconds..."
    sleep 10
done

echo "Waiting for RabbitMQ operator to be ready..."
kubectl wait --for=condition=available --timeout=240s deployment/rabbitmq-cluster-operator -n rabbitmq-system

echo "Deploying RabbitMQ cluster..."
# The operator's readiness probe covers its health port (8081), not the webhook
# port (9443), so the deployment reports available before the admission webhook
# accepts connections. Poll the actual apply rather than sleeping a fixed amount.
deadline=$((SECONDS + 180))
until kubectl apply -f infrastructure/rabbitmq/rabbitmq-cluster.yaml; do
    if [ "$SECONDS" -ge "$deadline" ]; then
        echo "❌ Timed out waiting for the RabbitMQ operator webhook to accept the cluster manifest"
        exit 1
    fi
    echo "⚠️  Operator webhook not ready yet, retrying in 5 seconds..."
    sleep 5
done

echo "Waiting for RabbitMQ cluster to be ready..."
kubectl wait --for=condition=AllReplicasReady rabbitmqcluster/rabbitmq -n default --timeout=180s || {
    echo "⚠️  RabbitMQ cluster is taking longer than expected to start"
    echo "Check status with: kubectl get rabbitmqcluster -n default"
}

echo "RabbitMQ deployed successfully!"
