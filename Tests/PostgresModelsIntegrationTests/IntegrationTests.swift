import Testing
import PostgresNIO
import Logging
import Foundation

private let postgresAvailable = ProcessInfo.processInfo.environment["PGHOST"] != nil

private func makeClient() -> PostgresClient {
    let env = ProcessInfo.processInfo.environment
    return PostgresClient(configuration: .init(
        host: env["PGHOST"] ?? "localhost",
        port: Int(env["PGPORT"] ?? "5432") ?? 5432,
        username: env["PGUSER"] ?? "postgres",
        password: env["PGPASSWORD"] ?? "",
        database: env["PGDATABASE"] ?? "postgres",
        tls: .disable
    ))
}

private func withClient(_ work: (PostgresClient) async throws -> Void) async throws {
    let client = makeClient()
    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask { await client.run() }
        try await work(client)
        group.cancelAll()
    }
}

private let log: Logger = {
    var l = Logger(label: "postgres-models.test")
    l.logLevel = .warning
    return l
}()

// Replicates the logic emitted by MigrationCodeGenerator.generateRunFunction()
private func runMigrations(
    _ migrations: [(name: String, sql: String)],
    client: PostgresClient
) async throws {
    try await client.query("""
        CREATE TABLE IF NOT EXISTS postgres_models_migrations (
            name TEXT PRIMARY KEY,
            run_at TIMESTAMPTZ NOT NULL DEFAULT now()
        )
        """, logger: log)
    for (name, sql) in migrations {
        let existing = try await client.query(
            "SELECT 1 FROM postgres_models_migrations WHERE name = \(name)",
            logger: log
        )
        var alreadyRun = false
        for try await _ in existing { alreadyRun = true; break }
        guard !alreadyRun else { continue }
        try await client.withConnection { conn in
            try await conn.query("BEGIN", logger: log)
            do {
                try await conn.query(PostgresQuery(unsafeSQL: sql), logger: log)
                try await conn.query(
                    "INSERT INTO postgres_models_migrations (name) VALUES (\(name))",
                    logger: log
                )
                try await conn.query("COMMIT", logger: log)
            } catch {
                try? await conn.query("ROLLBACK", logger: log)
                throw error
            }
        }
    }
}

// MARK: - Migration Runner Tests

@Suite("Migration Runner", .serialized)
struct MigrationRunnerTests {
    @Test(.enabled(if: postgresAvailable))
    func createsTrackingTableIfNotExists() async throws {
        try await withClient { client in
            try await client.query(
                "DROP TABLE IF EXISTS postgres_models_migrations",
                logger: log
            )
            try await runMigrations([], client: client)
            let rows = try await client.query(
                "SELECT 1 FROM information_schema.tables WHERE table_name = 'postgres_models_migrations'",
                logger: log
            )
            var found = false
            for try await _ in rows { found = true }
            #expect(found)
        }
    }

    @Test(.enabled(if: postgresAvailable))
    func runsMigrationAndRecordsName() async throws {
        try await withClient { client in
            try await client.query("DROP TABLE IF EXISTS migration_items CASCADE", logger: log)
            try await client.query("DROP TABLE IF EXISTS postgres_models_migrations", logger: log)
            let name = "001_create_migration_items"
            try await runMigrations(
                [(name: name, sql: "CREATE TABLE migration_items (id UUID PRIMARY KEY)")],
                client: client
            )
            let recorded = try await client.query(
                "SELECT 1 FROM postgres_models_migrations WHERE name = \(name)",
                logger: log
            )
            var wasRecorded = false
            for try await _ in recorded { wasRecorded = true }
            #expect(wasRecorded)
            let tableExists = try await client.query(
                "SELECT 1 FROM information_schema.tables WHERE table_name = 'migration_items'",
                logger: log
            )
            var created = false
            for try await _ in tableExists { created = true }
            #expect(created)
        }
    }

    @Test(.enabled(if: postgresAvailable))
    func skipsAlreadyRunMigration() async throws {
        try await withClient { client in
            try await client.query("DROP TABLE IF EXISTS idempotent_items CASCADE", logger: log)
            try await client.query("DROP TABLE IF EXISTS postgres_models_migrations", logger: log)
            let migrations = [(name: "001_idempotent", sql: "CREATE TABLE idempotent_items (id UUID PRIMARY KEY)")]
            try await runMigrations(migrations, client: client)
            // Second run must not fail with a PRIMARY KEY violation on the tracking table
            try await runMigrations(migrations, client: client)
            let name = "001_idempotent"
            let rows = try await client.query(
                "SELECT 1 FROM postgres_models_migrations WHERE name = \(name)",
                logger: log
            )
            var count = 0
            for try await _ in rows { count += 1 }
            #expect(count == 1)
        }
    }
}

// MARK: - Query Pattern Tests

@Suite("Query Patterns", .serialized)
struct QueryPatternTests {
    @Test(.enabled(if: postgresAvailable))
    func execInsertOneSelectManySelectDeletePatterns() async throws {
        try await withClient { client in
            try await client.query(
                PostgresQuery(unsafeSQL: "DROP TABLE IF EXISTS qp_items"),
                logger: log
            )
            try await client.query(
                PostgresQuery(unsafeSQL: "CREATE TABLE qp_items (id UUID PRIMARY KEY, label TEXT NOT NULL)"),
                logger: log
            )

            let id1 = UUID()
            let id2 = UUID()

            // :exec INSERT pattern
            try await client.query(
                "INSERT INTO qp_items (id, label) VALUES (\(id1), \("alpha"))",
                logger: log
            )
            try await client.query(
                "INSERT INTO qp_items (id, label) VALUES (\(id2), \("beta"))",
                logger: log
            )

            // :one SELECT pattern
            let oneRows = try await client.query(
                "SELECT id, label FROM qp_items WHERE id = \(id1)",
                logger: log
            )
            var foundLabel: String? = nil
            for try await (_, label) in oneRows.decode((UUID, String).self) { foundLabel = label }
            #expect(foundLabel == "alpha")

            // :many SELECT pattern
            var labels: [String] = []
            for try await (_, label) in try await client.query(
                "SELECT id, label FROM qp_items ORDER BY label",
                logger: log
            ).decode((UUID, String).self) {
                labels.append(label)
            }
            #expect(labels == ["alpha", "beta"])

            // :exec DELETE pattern
            try await client.query("DELETE FROM qp_items WHERE id = \(id1)", logger: log)
            var remaining: [String] = []
            for try await (_, label) in try await client.query(
                "SELECT id, label FROM qp_items",
                logger: log
            ).decode((UUID, String).self) {
                remaining.append(label)
            }
            #expect(remaining == ["beta"])
        }
    }
}
