#!/usr/bin/env bash

set -eo pipefail

echo "Deploying RabbitMQ..."

# Install RabbitMQ Cluster Operator
if kubectl get deployment -n rabbitmq-system rabbitmq-cluster-operator &>/dev/null; then
    echo "RabbitMQ Cluster Operator already installed"
else
    echo "Installing RabbitMQ Cluster Operator..."
    OPERATOR_URL="https://github.com/rabbitmq/cluster-operator/releases/latest/download/cluster-operator.yml"

    for attempt in 1 2 3; do
        echo "Download attempt $attempt/3..."
        if kubectl apply -f "$OPERATOR_URL"; then
            echo "✓ Successfully installed RabbitMQ operator"
            break
        else
            if [ $attempt -eq 3 ]; then
                echo "❌ Failed to download RabbitMQ operator after 3 attempts"
                echo "Please check your internet connection and try again"
                exit 1
            fi
            echo "⚠️  Download failed, retrying in 5 seconds..."
            sleep 5
        fi
    done
fi

echo "Waiting for RabbitMQ operator to be ready..."
kubectl wait --for=condition=available --timeout=120s deployment/rabbitmq-cluster-operator -n rabbitmq-system

echo "Deploying RabbitMQ cluster..."
kubectl apply -f infrastructure/rabbitmq/rabbitmq-cluster.yaml

echo "Waiting for RabbitMQ cluster to be ready..."
kubectl wait --for=condition=AllReplicasReady rabbitmqcluster/rabbitmq -n default --timeout=180s || {
    echo "⚠️  RabbitMQ cluster is taking longer than expected to start"
    echo "Check status with: kubectl get rabbitmqcluster -n default"
}

echo "RabbitMQ deployed successfully!"
echo ""
echo "RabbitMQ Status:"
kubectl get rabbitmqcluster -n default
kubectl get pods -n default -l 'app.kubernetes.io/name=rabbitmq'
echo ""
echo "RabbitMQ Management UI will be available via port-forward:"
echo "  kubectl port-forward -n default svc/rabbitmq 15672:15672"
echo "  Then access: http://localhost:15672"
echo "  Username: guest"
echo "  Password: guest"
