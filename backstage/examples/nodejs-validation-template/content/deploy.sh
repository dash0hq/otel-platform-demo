#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="${{ values.serviceName }}"
IMAGE_TAG="${IMAGE_TAG:-v1}"
KIND_CLUSTER="${KIND_CLUSTER:-otel-platform-demo}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

echo "==> Building Docker image ${SERVICE_NAME}:${IMAGE_TAG}"
docker build -t "${SERVICE_NAME}:${IMAGE_TAG}" .

echo "==> Loading image into kind cluster '${KIND_CLUSTER}'"
kind load docker-image --name "${KIND_CLUSTER}" "${SERVICE_NAME}:${IMAGE_TAG}"

echo "==> Applying Kubernetes manifests"
kubectl apply -f manifests/

if [ -d "dashboards" ] && compgen -G "dashboards/*.yaml" > /dev/null; then
  echo "==> Applying dashboard(s)"
  kubectl apply -f dashboards/
else
  echo "==> No dashboards found, skipping"
fi

echo "==> Done. ${SERVICE_NAME}:${IMAGE_TAG} deployed."
