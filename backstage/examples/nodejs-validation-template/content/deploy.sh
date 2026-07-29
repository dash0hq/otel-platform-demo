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

# Checked before the apply: on a first deploy the apply itself creates the pod with
# the new image, so no restart is needed.
ALREADY_DEPLOYED=false
if kubectl get deployment "${SERVICE_NAME}" >/dev/null 2>&1; then
  ALREADY_DEPLOYED=true
fi

echo "==> Applying Kubernetes manifests"
kubectl apply -f manifests/

# The image tag never changes, so on a re-deploy the Deployment spec is identical
# and `kubectl apply` is a no-op -- the pod would keep running the previous image
# even though a new one was just built and loaded. Restart to pick it up.
if [ "${ALREADY_DEPLOYED}" = true ]; then
  echo "==> Restarting deployment to pick up the rebuilt image"
  kubectl rollout restart "deployment/${SERVICE_NAME}"
fi

echo "==> Waiting for rollout to finish"
kubectl rollout status "deployment/${SERVICE_NAME}" --timeout=180s

if [ -d "dashboards" ] && compgen -G "dashboards/*.yaml" > /dev/null; then
  echo "==> Applying dashboard(s)"
  kubectl apply -f dashboards/
else
  echo "==> No dashboards found, skipping"
fi

echo "==> Done. ${SERVICE_NAME}:${IMAGE_TAG} deployed."
