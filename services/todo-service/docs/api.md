# API

Base path `/todos` on port `3000`. Reachable through the frontend proxy at
`http://localhost:3001/todos` once `01_start-demo.sh` is running.

## Endpoints

| Method | Path | Notes |
|---|---|---|
| `GET` | `/todos` | Returns a Spring `Page`, not a bare array |
| `POST` | `/todos` | Creates a todo; validated when validation is enabled |
| `GET` | `/todos/{id}` | 404 via `ResourceNotFoundException` if absent |
| `DELETE` | `/todos/{id}` | Publishes `todo.deleted` |

## The payload field is `name`

```json
{ "name": "buy milk" }
```

Not `title`. Posting `{"title": "..."}` fails the `@NotBlank` constraint on `name`
and returns a validation error, which looks confusingly like a
`validation-service` rejection but is Spring's own bean validation.

## `GET /todos` returns a page, not a list

```json
{ "content": [ ... ], "totalElements": 11, "totalPages": 2, "number": 0 }
```

Count todos with `.totalElements`. Taking `len()` of the response object yields the
number of pagination keys in the wrapper — a trap worth knowing, because it returns
a plausible-looking small integer rather than failing.

## Examples

```bash
# create
curl -s -X POST http://localhost:3001/todos \
  -H 'Content-Type: application/json' \
  -d '{"name":"buy milk"}'

# how many todos exist
curl -s http://localhost:3001/todos | python3 -c 'import sys,json;print(json.load(sys.stdin)["totalElements"])'
```

## Rejection behaviour

With validation enabled, a name containing `bad`, `terrible` or `awful` is
rejected. Anything else — including the word "spam" — is accepted, so pick a real
bad word when demonstrating a rejection or the request will succeed and look like a
broken feature.
