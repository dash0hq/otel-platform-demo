# Operations

## Configuration

| Variable | Value in the demo |
|---|---|
| `SPRING_DATASOURCE_URL` | `jdbc:mysql://my-mysql.default.svc.cluster.local:3306/notification` |
| `SPRING_DATASOURCE_USERNAME` / `_PASSWORD` | `notification` / `mysecretPassword` |
| `RABBITMQ_HOST` / `_PORT` | `rabbitmq.default.svc.cluster.local` / `5672` |
| `RABBITMQ_USERNAME` / `_PASSWORD` | `guest` / `guest` |

It shares the MySQL instance with `todo-service` but uses its own `notification`
database.

## Is it actually consuming?

Ask the broker rather than reading logs — a `--since` window that predates the
events reports nothing and looks like a broken consumer:

```bash
kubectl exec rabbitmq-server-0 -- rabbitmqctl list_queues name messages consumers
```

Healthy output has `consumers=1` and `messages=0` for `todo.created` and
`todo.deleted`. A rising `messages` count with `consumers=0` means this service is
down or failed to bind.

End-to-end check:

```bash
curl -s -X POST http://localhost:3001/todos -H 'Content-Type: application/json' -d '{"name":"probe"}'
sleep 2
curl -s http://localhost:3001/notifications/count
```

The count should increase by one.

## Telemetry

Instrumented by the OpenTelemetry Operator, emitting the **stable** HTTP semantic
conventions (`http.request.method`, `http.response.status_code`). JVM memory is
`jvm_memory_used_bytes` — the dashboard in `dashboards/` uses that name, and the
older `process_runtime_jvm_memory_usage_bytes` returns nothing.

Consumer spans are linked to the producing trace through the message headers, so a
notification's work shows up under the original browser click. If it instead
appears as its own root trace, propagation is broken — that is the signal to look
at, not the presence of spans.

## Restarting

The image tag never changes (`v1`), so `kubectl apply` alone will not replace a
running pod:

```bash
kubectl rollout restart deployment/notification-service
kubectl rollout status deployment/notification-service --timeout=180s
```
