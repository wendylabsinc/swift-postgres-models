# TodoApp Example

A minimal todo app demonstrating hummingbird-sql. At build time, the plugin generates `TodosQueries` and `Migrations` from the two `.sql` files in this target.

## Prerequisites

A running PostgreSQL instance. With Docker:

```bash
docker run --rm -d \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=password \
  -e POSTGRES_DB=todos \
  -p 5432:5432 \
  postgres:16
```

## Run

```bash
cd Examples/TodoApp
PGPASSWORD=password swift run
```

Environment variables (all optional, shown with defaults):

| Variable | Default |
|----------|---------|
| `PGHOST` | `localhost` |
| `PGPORT` | `5432` |
| `PGUSER` | `postgres` |
| `PGPASSWORD` | _(empty)_ |
| `PGDATABASE` | `todos` |

## What it demonstrates

- **`001_create_todos.migration.sql`** → `Migrations.swift` with a transactional runner and a tracking table so migrations are applied exactly once
- **`todos.query.sql`** → `TodosQueries.swift` with five typed static methods:
  - `createTodo(_:id:title:logger:)` — `:exec`
  - `listTodos(_:logger:)` — `:many` returning `[(id: UUID, title: String, done: Bool)]`
  - `getTodo(_:id:logger:)` — `:one` returning `(id: UUID, title: String, done: Bool)?`
  - `completeTodo(_:id:logger:)` — `:exec`
  - `deleteTodo(_:id:logger:)` — `:exec`
