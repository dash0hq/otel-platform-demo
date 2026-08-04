# Operations

## Deploying

The scaffolder writes the files but does not deploy them. The bundled script builds
the image, loads it into the kind cluster, applies the manifests and the dashboard,
and waits for the rollout:

```bash
bash services/${{ values.serviceName }}/deploy.sh
```

It restarts the Deployment when one already exists. That step is essential: the image
tag is always `v1`, so a rebuilt image produces an identical pod spec and
`kubectl apply` alone leaves the old container running.

## Turning it on

Deploying is not enough — `todo-service` ships with the call disabled:

```bash
kubectl set env deployment/todo-service VALIDATION_SERVICE_ENABLED=true
kubectl rollout status deployment/todo-service
```

Confirm the value from a **running** pod. A terminating pod still appears in
`kubectl get pods`, so `.items[0]` can report the old value:

```bash
kubectl get pods -l app.kubernetes.io/name=todo-service \
  --field-selector=status.phase=Running \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].env[?(@.name=="VALIDATION_SERVICE_ENABLED")].value}{"\n"}{end}'
```

## Verifying end to end

```bash
# should be accepted
curl -s -X POST http://localhost:3001/todos -H 'Content-Type: application/json' \
  -d '{"name":"buy milk"}'

# should be rejected -- contains "bad"
curl -s -X POST http://localhost:3001/todos -H 'Content-Type: application/json' \
  -d '{"name":"a bad idea"}'
```

The rejection should appear in the trace on `todo-service`'s span as
`validation.failed`, and this service should show a corresponding child span.

## Configuration

| Variable | Purpose |
|---|---|
| `OTEL_SERVICE_NAME` | Sets `service.name`; already set to `${{ values.serviceName }}` in the manifest |
| `PORT` | Listen port, defaults to `${{ values.port }}` |

## Removing it

The service directory is deliberately gitignored so the repo can be reset for a
fresh run of the demo:

```bash
./02_cleanup.sh            # removes the scaffolded service too
./02_cleanup.sh --keep-scaffolded
```

The catalog entry disappears on its own once the directory is gone, because the
catalog discovers services by scanning `services/*/catalog-info.yaml`.
