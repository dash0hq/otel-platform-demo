# notification-service

The consumer side of the demo. It subscribes to todo lifecycle events on RabbitMQ,
records a notification row per event, and exposes them over a small read API.

Owned by **notifications-team**.

## At a glance

| | |
|---|---|
| Language / runtime | Java 17, Spring Boot |
| Listens on | `3002` (`/notifications`) |
| Database | MySQL — `my-mysql.default.svc.cluster.local:3306/notification` |
| Consumes | RabbitMQ queues `todo.created`, `todo.deleted` |
| Called by | `frontend`, via its `/notifications` proxy |

Note the port: **3002**, not 3000. It is the one service in the demo that does not
use its framework's default.

## Why it matters in the demo

It is the asynchronous half of the trace. Because trace context travels in the
RabbitMQ message headers, work done here appears as a child span of the original
browser click rather than as a disconnected trace — which is the point worth
showing, since message-boundary propagation is where naive setups usually break.

It also owns the two API contracts in the catalog (`notification-api` and
`rabbitmq-events`), so it is a good example of a team owning an interface that a
different team publishes to.

## Where to look next

- [Architecture](architecture.md) — the consumer wiring and event contract
- [Operations](operations.md) — configuration and verifying consumption
