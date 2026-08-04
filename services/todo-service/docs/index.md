# todo-service

The write side of the demo. `todo-service` owns the todo domain: it stores todos in
MySQL, optionally checks new names against `validation-service`, and publishes an
event to RabbitMQ for every todo created or deleted.

Owned by **todo-team**.

## At a glance

| | |
|---|---|
| Language / runtime | Java 17, Spring Boot |
| Listens on | `3000` (`/todos`) |
| Database | MySQL — `my-mysql.default.svc.cluster.local:3306/todo` |
| Publishes to | RabbitMQ exchange `todo.events` |
| Calls | `validation-service` (only when enabled) |
| Called by | `frontend`, via its `/todos` proxy |

## Why it matters in the demo

It is the service that ties the whole trace together. A single click in the
frontend produces one distributed trace that passes through nginx, this service,
MySQL, `validation-service`, and RabbitMQ into `notification-service` — which makes
it the best place to demonstrate context propagation across HTTP *and* messaging.

It is also where the validation feature flag lives, so it is the switch used to
show a newly scaffolded service joining an existing trace.

## Where to look next

- [Architecture](architecture.md) — dependencies and the event contract
- [API](api.md) — the endpoints
- [Operations](operations.md) — configuration, probing, and telemetry
