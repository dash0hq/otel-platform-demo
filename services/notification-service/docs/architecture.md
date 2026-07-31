# Architecture

```mermaid
flowchart LR
    TS[todo-service] -->|publish| EX{{exchange todo.events}}
    EX -->|todo.created| Q1[[queue todo.created]]
    EX -->|todo.deleted| Q2[[queue todo.deleted]]
    Q1 --> NC[NotificationConsumer]
    Q2 --> NC
    NC --> DB[(MySQL<br/>notification)]
    FE[frontend] -->|GET /notifications| NCtl[NotificationController<br/>:3002]
    NCtl --> DB
```

## Code layout

| Class | Responsibility |
|---|---|
| `NotificationConsumer` | Two `@RabbitListener` methods, one per queue |
| `RabbitMQConfig` | Declares exchange `todo.events`, queues and bindings |
| `TodoEvent` | Inbound message payload |
| `Notification` / `NotificationRecord` | Persisted notification |
| `NotificationController` | Read API, `@RequestMapping("/notifications")`, `@CrossOrigin` |

## Read API

| Method | Path | Returns |
|---|---|---|
| `GET` | `/notifications` | The 50 most recent, newest first (`findTop50ByOrderByReceivedAtDesc`) |
| `GET` | `/notifications/count` | Total row count as a bare number |

Unlike `todo-service`, these are **not** paginated — `/notifications` returns a
plain JSON array, so `len()` on the response is the correct way to count it.

## Event contract

Bound to exchange `todo.events`:

| Queue | Routing key |
|---|---|
| `todo.created` | `todo.created` |
| `todo.deleted` | `todo.deleted` |

Both this service and `todo-service` declare the exchange and queues, so startup
order does not matter — whichever comes up first creates the topology.

The queues are durable, so events published while this service is down are
delivered once it returns. That makes "stop the consumer, create some todos, start
it again" a reliable way to demonstrate a backlog draining.
