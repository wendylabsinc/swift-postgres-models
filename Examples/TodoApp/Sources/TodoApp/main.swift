import Foundation
import Logging
import PostgresNIO

LoggingSystem.bootstrap(StreamLogHandler.standardOutput)
var logger = Logger(label: "TodoApp")
logger.logLevel = .warning

let env = ProcessInfo.processInfo.environment
let config = PostgresClient.Configuration(
    host: env["PGHOST"] ?? "localhost",
    port: Int(env["PGPORT"] ?? "5432").flatMap { $0 } ?? 5432,
    username: env["PGUSER"] ?? "postgres",
    password: env["PGPASSWORD"] ?? "",
    database: env["PGDATABASE"] ?? "todos",
    tls: .disable
)

let client = PostgresClient(configuration: config)

try await withThrowingTaskGroup(of: Void.self) { group in
    group.addTask { await client.run() }

    // Run migrations (idempotent — safe to call on every startup)
    print("Running migrations...")
    try await Migrations.run(client: client, logger: logger)

    // Create a couple of todos
    let id1 = UUID()
    let id2 = UUID()
    try await TodosQueries.createTodo(client, id: id1, title: "Buy groceries", logger: logger)
    try await TodosQueries.createTodo(client, id: id2, title: "Write more tests", logger: logger)
    print("Created 2 todos")

    // List all todos
    let todos = try await TodosQueries.listTodos(client, logger: logger)
    print("\nAll todos (\(todos.count)):")
    for todo in todos {
        print("  [\(todo.done ? "x" : " ")] \(todo.title)")
    }

    // Complete one
    try await TodosQueries.completeTodo(client, id: id1, logger: logger)

    // Fetch it back to verify
    if let updated = try await TodosQueries.getTodo(client, id: id1, logger: logger) {
        print("\nAfter completion: '\(updated.title)' done=\(updated.done)")
    }

    // Delete the other
    try await TodosQueries.deleteTodo(client, id: id2, logger: logger)

    // Final list
    let remaining = try await TodosQueries.listTodos(client, logger: logger)
    print("\nFinal todos (\(remaining.count)):")
    for todo in remaining {
        print("  [\(todo.done ? "x" : " ")] \(todo.title)")
    }

    group.cancelAll()
}
