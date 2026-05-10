# swift-postgres-models

A SwiftPM build tool plugin that generates typed PostgreSQL query helpers and a migration runner from plain SQL files. Write SQL, get type-safe Swift.

No ORM. No DSL. No runtime library. The generated code talks directly to [PostgresNIO](https://github.com/vapor/postgres-nio).

## How it works

Add `.query.sql` and `.migration.sql` files to your target. At build time, the plugin generates a `<Name>Queries` struct per query file and a single `Migrations` struct for all migration files. The generated Swift is compiled as part of your target — no extra dependencies beyond PostgresNIO.

## Installation

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/wendylabsinc/swift-postgres-models.git", from: "1.0.0"),
    .package(url: "https://github.com/vapor/postgres-nio.git", from: "1.21.0"),
],
targets: [
    .executableTarget(
        name: "MyApp",
        dependencies: [
            .product(name: "PostgresNIO", package: "postgres-nio"),
        ],
        plugins: [
            .plugin(name: "PostgresModelsPlugin", package: "swift-postgres-models"),
        ]
    ),
]
```

**Requirements:** Swift 6, macOS 14+

## Queries

Create a file with the `.query.sql` extension anywhere in your target's source directory. Annotate each query with comments:

```sql
-- @query GetUser :one
-- @param id: UUID
-- @returns id: UUID, name: String, email: String?
SELECT id, name, email FROM users WHERE id = $1;

-- @query ListUsers :many
-- @returns id: UUID, name: String, email: String?
SELECT id, name, email FROM users ORDER BY name;

-- @query CreateUser :exec
-- @param id: UUID
-- @param name: String
-- @param email: String?
INSERT INTO users (id, name, email) VALUES ($1, $2, $3);
```

From `users.query.sql`, the plugin generates `UsersQueries` with static methods:

```swift
// :one — returns the first row or nil
let user = try await UsersQueries.getUser(client, id: id, logger: logger)

// :many — returns an array
let users = try await UsersQueries.listUsers(client, logger: logger)

// :exec — no return value
try await UsersQueries.createUser(client, id: id, name: name, email: email, logger: logger)
```

### Annotation reference

| Annotation | Format | Notes |
|------------|--------|-------|
| `@query` | `-- @query <Name> :<kind>` | Required. Starts a query block. |
| `@param` | `-- @param <name>: <Type>` | One per `$1`, `$2`, … placeholder, in order. |
| `@returns` | `-- @returns <name>: <Type>, …` | Required for `:one` and `:many`. Single comma-separated line. |

**Kinds:**
- `:one` — `async throws -> T?` — returns the first row, or `nil`
- `:many` — `async throws -> [T]` — collects all rows into an array
- `:exec` — `async throws -> Void` — no return value

**Supported types:** `UUID`, `String`, `Int`, `Double`, `Bool`, `Date`, and optionals of each (`UUID?`, `String?`, etc.)

**File → struct naming:** the file stem is split on `_` and `-`, each word capitalised, then joined with a `Queries` suffix. `todo_items.query.sql` → `TodoItemsQueries`.

**SQL injection safety:** PostgresNIO's `PostgresQuery` string interpolation is used for all parameters — `\(value)` binds the value as a prepared statement parameter, never raw-interpolated into the query string.

## Migrations

Create files with the `.migration.sql` extension. No annotations needed — just plain SQL:

```sql
-- 001_create_users.migration.sql
CREATE TABLE users (
    id    UUID PRIMARY KEY,
    name  TEXT NOT NULL,
    email TEXT
);
```

Files are sorted lexicographically before embedding, so numeric prefixes control order. All migrations across all `.migration.sql` files in your target are combined into a single `Migrations.swift`.

At app startup, call:

```swift
try await Migrations.run(client: client, logger: logger)
```

The runner creates a `postgres_models_migrations` tracking table on first run, then applies each migration exactly once inside a transaction. Already-applied migrations are skipped.

## Example

A working todo app is in [`Examples/TodoApp`](Examples/TodoApp). It demonstrates migrations, all three query kinds, and environment-variable-based connection config.

```bash
# Start Postgres
docker run --rm -d \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=password \
  -e POSTGRES_DB=todos \
  -p 5432:5432 \
  postgres:16

# Run the example
cd Examples/TodoApp
PGPASSWORD=password swift run
```

## Error handling

Build errors are reported with file and line context. Common mistakes caught at build time:

| Error | Cause |
|-------|-------|
| `missing query kind` | `@query` line has no `:one`, `:many`, or `:exec` |
| `unknown query kind` | Typo in the kind |
| `param count mismatch` | Number of `@param` lines doesn't match `$N` placeholders in the SQL |
| `unsupported type` | A type in `@param` or `@returns` isn't in the supported list |
| `query '…' has no @returns` | `:one` or `:many` query is missing an `@returns` line |
| `query '…' has no SQL body` | Annotations present but no SQL statement follows |
