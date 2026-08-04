# ${{ values.serviceName }}

${{ values.description }}

This service was created from the **Node.js Validation Service** template in
Backstage, which is the point of the demo: a developer fills in a form, and a fully
instrumented service appears in the catalog with docs, a dashboard, Kubernetes
manifests and a deploy script already in place.

Owned by **${{ values.owner }}**.

## At a glance

| | |
|---|---|
| Language / runtime | Node.js 24, Express |
| Listens on | `${{ values.port }}` |
| Endpoints | `POST /validate/todo-name`, `GET /health` |
| Called by | `todo-service`, when validation is enabled |
| Logging | Winston, JSON format |
| Telemetry | OpenTelemetry auto-instrumentation |

## Why it matters in the demo

It is the service that does not exist at the start. The cluster boots without it and
`todo-service` runs with `VALIDATION_SERVICE_ENABLED=false`; scaffolding this
service and flipping that flag makes a **new hop appear inside an existing
distributed trace** — which is a much stronger demonstration than showing a service
that was always there.

## Where to look next

- [Architecture](architecture.md) — how it fits into the request path
- [Operations](operations.md) — deploying it and turning it on
