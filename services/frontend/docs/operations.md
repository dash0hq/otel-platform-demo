# Operations

## Configuration

| Variable | Value in the demo |
|---|---|
| `TODO_SERVICE_HOST` / `TODO_SERVICE_PORT` | `todo-service` / `3000` |
| `OTEL_COLLECTOR_HOST` / `OTEL_COLLECTOR_PORT` | `otel-collector.opentelemetry.svc.cluster.local` / `4318` |

These are substituted into `nginx.conf.template` when the container starts, so
changing them requires a pod restart rather than an nginx reload.

## Build and deploy

```bash
docker build -t frontend:v1 services/frontend
kind load docker-image --name otel-platform-demo frontend:v1
kubectl rollout restart deployment/frontend
kubectl rollout status deployment/frontend --timeout=180s
```

The `rollout restart` is not optional. The tag is always `v1`, so `kubectl apply`
sees an unchanged pod spec and leaves the old image running — the most common way to
"deploy" a change here and see nothing happen.

## Accessing it

`01_start-demo.sh` port-forwards `svc/frontend` to **3001** on the host (container
port 80). Note that 3000 belongs to the Backstage frontend, not this one.

## Toolchain constraint

The build still uses `react-scripts` 5.0.1, which is unmaintained. It works with
Node 24 today, but it is the part of this repo most likely to break on a future Node
bump, and it will not benefit from newer build tooling. Migrating to Vite is the
known fix and has not been done.

## Verifying the browser telemetry path

A click in the UI should produce a root span in Dash0 with child spans from the
backend services. If browser spans are missing entirely, check the proxy hop first:

```bash
kubectl exec deployment/frontend -- \
  curl -s -o /dev/null -w '%{http_code}\n' -X POST \
  http://otel-collector.opentelemetry.svc.cluster.local:4318/v1/traces \
  -H 'Content-Type: application/json' -d '{}'
```

A `400` is the healthy answer here: the collector rejected an empty payload, which
proves it is reachable. Connection refused or a timeout means the upstream name or
port is wrong.
