#!/usr/bin/env bash

set -eo pipefail

echo "Installing Perses Operator CRDs and deploying the operator..."
kustomize build 'github.com/perses/perses-operator/config/default?ref=v0.4.0' | kubectl apply --server-side --force-conflicts -f -

echo "Waiting for Perses operator to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/perses-operator-controller-manager -n perses-operator-system

echo "Deploying Perses instance..."
kubectl apply -f ./infrastructure/perses/perses.yaml

echo "Waiting for Perses to be ready..."
sleep 10
kubectl wait --for=condition=ready --timeout=300s pod -l app.kubernetes.io/name=perses -n default

echo "Deploying Prometheus datasource..."
kubectl apply -f ./infrastructure/perses/prometheus-datasource.yaml

# Dashboards that ship with a service in this repo. Services scaffolded through
# Backstage apply their own dashboard from their deploy.sh, so they are not
# required to exist here -- this only covers the ones committed to the repo.
echo "Deploying service dashboards..."
for dashboard_dir in ./services/*/dashboards; do
    [ -d "$dashboard_dir" ] || continue
    compgen -G "$dashboard_dir/*.yaml" > /dev/null || continue
    kubectl apply -f "$dashboard_dir"
done

echo "Perses deployed successfully!"
