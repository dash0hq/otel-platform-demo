# Operations

## Configuration

Set in `manifests/deploy.yaml`:

| Variable | Value in the demo |
|---|---|
| `SPRING_DATASOURCE_URL` | `jdbc:mysql://my-mysql.default.svc.cluster.local.:3306/todo` |
| `SPRING_DATASOURCE_USERNAME` / `_PASSWORD` | `todo` / `mysecretPassword` |
| `RABBITMQ_HOST` / `_PORT` | `rabbitmq.default.svc.cluster.local` / `5672` |
| `RABBITMQ_USERNAME` / `_PASSWORD` | `guest` / `guest` |
| `VALIDATION_SERVICE_ENABLED` | **`false`** |
| `VALIDATION_SERVICE_URL` | `http://validation-service:3001` |

`VALIDATION_SERVICE_ENABLED` ships as `false` on purpose: `validation-service` does
not exist until someone scaffolds it in Backstage. Flipping it to `true` is the
payoff of the scaffolder demo.

```bash
kubectl set env deployment/todo-service VALIDATION_SERVICE_ENABLED=true
kubectl rollout status deployment/todo-service
```

## Verifying a change landed

The image tag is always `v1`, so `kubectl apply` after a rebuild changes nothing in
the pod spec and the old container keeps running. Restart explicitly:

```bash
kubectl rollout restart deployment/todo-service
kubectl rollout status deployment/todo-service --timeout=180s
```

Read configuration back from the **running** pod, and beware that a terminating pod
still answers `kubectl get pods`. Selecting `.items[0]` can return the pod being
replaced and show you the previous value:

```bash
kubectl get pods -l app.kubernetes.io/name=todo-service \
  --field-selector=status.phase=Running \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].env[?(@.name=="VALIDATION_SERVICE_ENABLED")].value}{"\n"}{end}'
```

## Telemetry

Instrumented by the OpenTelemetry Operator via an annotation, so there is no SDK
wiring in the source. It emits the **stable** HTTP semantic conventions
(`http.request.method`, `http.response.status_code`) — unlike the Node services,
which still emit the legacy `http.method` / `http.status_code`. Both generations
coexist in this demo, so a dashboard query written for one will silently return no
data for the other.

JVM metrics arrive as `jvm_memory_used_bytes` (not the older
`process_runtime_jvm_memory_usage_bytes`).

Validation outcomes are recorded as span attributes rather than logs:
`validation.result`, `validation.message`, `validation.failed`.

## Checking the queue actually drained

`--since` windows mislead here: if the events fired earlier than the window, logs
report nothing and it looks like no events were consumed. Ask RabbitMQ instead:

```bash
kubectl exec rabbitmq-server-0 -- rabbitmqctl list_queues name messages consumers
```

`consumers=1, messages=0` on `todo.created` means the consumer is attached and
keeping up.
