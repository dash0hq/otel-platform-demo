# frontend

The React UI for the todo application, served by nginx. It is also the edge proxy
for the whole demo: browser calls to the backend services and to the OpenTelemetry
collector all go through it, so everything is same-origin and there is no CORS to
configure.

Owned by **web-team**.

## At a glance

| | |
|---|---|
| Language / runtime | React (TypeScript), built with `react-scripts` |
| Served by | nginx, listening on `80` |
| Local URL | `http://localhost:3001` (port-forward from `01_start-demo.sh`) |
| Catalog type | `website` — which is why "what services do we have" excludes it |
| Consumes | `todo-api` |

## Why it matters in the demo

It is where a trace begins. Browser spans are exported through this same nginx to
the collector, so a click in the UI becomes the root span of a trace that continues
through `todo-service`, MySQL, `validation-service` and RabbitMQ into
`notification-service`. Without the proxy hop, browser telemetry would be a
separate island.

## Where to look next

- [Architecture](architecture.md) — the proxy routes and why they exist
- [Operations](operations.md) — build, config and known toolchain constraints
