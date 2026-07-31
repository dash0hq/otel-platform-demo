# Architecture

```mermaid
flowchart LR
    FE[frontend] -->|POST /todos| TS[todo-service:3000]
    TS -->|POST /validate/todo-name| VS[${{ values.serviceName }}<br/>:${{ values.port }}]
    VS -->|accepted / rejected| TS
    TS -->|on accept| MQ{{RabbitMQ todo.events}}
```

`todo-service` only makes this call when `VALIDATION_SERVICE_ENABLED=true`. Until
then this service receives no traffic, which is expected rather than broken.

## Endpoints

### `POST /validate/todo-name`

```json
{ "name": "buy milk" }
```

Responds with the validation verdict. A name is **rejected** when the lowercased
value contains any of:

- `bad`
- `terrible`
- `awful`

Everything else is accepted. This matters when demonstrating a rejection: plausible
test words like "spam" or "invalid" are *not* on the list, so the request succeeds
and it looks as though validation is not wired up. Use a name containing `bad`.

### `GET /health`

Liveness/readiness probe target. Returns a static healthy response.

## Trace propagation

The call from `todo-service` arrives with W3C trace context on the request, and the
OpenTelemetry auto-instrumentation continues that trace rather than starting a new
one. The result is one trace spanning browser → nginx → `todo-service` → this
service → RabbitMQ → `notification-service`.

`todo-service` also records the outcome on its own span as `validation.result`,
`validation.message` and `validation.failed`, so a rejection is visible in the trace
without reading logs.

## Semantic conventions

Node auto-instrumentation emits the **legacy** HTTP attributes — `http.method`,
`http.status_code` — not the stable `http.request.method` /
`http.response.status_code` that the Java services emit. Upgrading
`@opentelemetry/auto-instrumentations-node` does not change this; the opt-in is
`OTEL_SEMCONV_STABILITY_OPT_IN=http`. Dashboard queries for this service must use the
legacy names.
