#!/usr/bin/env bash

set -eo pipefail

CLUSTER_NAME=${CLUSTER_NAME:-otel-platform-demo}

# Services created live during the demo by the Backstage scaffolder. These are
# generated output (gitignored), not source -- the source is the template under
# backstage/examples/. Removing them resets the repo for the next demo run.
SCAFFOLDED_SERVICES=(services/validation-service)

KEEP_SCAFFOLDED=false

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Tears down the demo: deletes the kind cluster and removes services that were
scaffolded through Backstage during the demo.

Options:
  --keep-scaffolded   Delete the cluster but keep scaffolded services on disk.
                      Use when rebuilding the cluster without re-scaffolding.
  -h, --help          Show this help message

EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --keep-scaffolded)
            KEEP_SCAFFOLDED=true
            shift
            ;;
        -h|--help)
            show_usage
            ;;
        *)
            echo "Error: Unknown option $1"
            show_usage
            ;;
    esac
done

echo "Deleting kind cluster: $CLUSTER_NAME"
# Deleting the cluster takes the scaffolded workloads with it -- Deployment,
# Service and PersesDashboard all live in the cluster, so there is nothing to
# unwind individually.
kind delete cluster --name="$CLUSTER_NAME"

if [ "$KEEP_SCAFFOLDED" = true ]; then
    echo "Keeping scaffolded services on disk (--keep-scaffolded)"
else
    for dir in "${SCAFFOLDED_SERVICES[@]}"; do
        if [ -d "$dir" ]; then
            echo "Removing scaffolded service: $dir"
            rm -rf "$dir"
        fi
    done
fi

echo "Cleanup complete!"
echo ""
echo "Note: a scaffolded service also disappears from the Backstage catalog on its"
echo "own within ~10s, because the catalog discovers services by scanning"
echo "services/*/catalog-info.yaml rather than from a static list."
