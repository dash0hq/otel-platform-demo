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

This service emits the **stable** HTTP semantic conventions —
`http.request.method`, `http.response.status_code` — matching the Java services.

Node auto-instrumentation defaults to the legacy v1.7.0 names (`http.method`,
`http.status_code`); the demo opts in with `OTEL_SEMCONV_STABILITY_OPT_IN=http`.

That variable is set in `infrastructure/instrumentations/instrumentation.yaml` under
`spec.nodejs.env`, **not** in this service. The SDK is injected by the OpenTelemetry
Operator: the pod is annotated `instrumentation.opentelemetry.io/inject-nodejs`, the
operator adds an init container and sets
`NODE_OPTIONS=--require /otel-auto-instrumentation-nodejs/autoinstrumentation.js`.
The `@opentelemetry/auto-instrumentations-node` entry in `package.json` is therefore
**not** what instruments this service at runtime — `npm start` runs plain
`node index.js` — so changing that dependency has no effect on the emitted
attributes. The `start:otel` script exists for running outside Kubernetes.

Because of the opt-in, the metric names are the stable ones, in **seconds**:

| Legacy (before the opt-in) | Stable (now) |
|---|---|
| `http_server_duration_milliseconds_count` | `http_server_request_duration_seconds_count` |
| `http_server_duration_milliseconds_bucket` | `http_server_request_duration_seconds_bucket` |
| `http_status_code` | `http_response_status_code` |

The dashboard in `dashboards/` queries the stable names and sets the p95 axis to
seconds. If you ever remove the opt-in, those four queries go silent rather than
erroring.

One exception remains: the `frontend` browser SDK still emits the legacy names. The
opt-in is an environment variable and there is no `process.env` in a browser, so it
cannot be applied there.
