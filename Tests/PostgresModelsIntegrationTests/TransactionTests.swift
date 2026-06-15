import Testing
import PostgresNIO
import Logging
import Foundation

// MARK: - Mirror of the generated PostgresModelsRuntime.swift
//
// The integration-test target doesn't depend on the generated runtime, so we
// reproduce the exact code RuntimeCodeGenerator emits here. This doubles as a
// compile-check that the emitted protocol and conformances build against real
// PostgresNIO, and lets the tests below exercise generated-style helpers that
// accept `some PostgresQueryRunner`.

protocol PostgresQueryRunner: Sendable {
    @discardableResult
    func query(_ query: PostgresQuery, logger: Logger, file: String, line: Int) async throws -> PostgresRowSequence
}

extension PostgresConnection: PostgresQueryRunner {}

extension PostgresClient: PostgresQueryRunner {
    func query(_ query: PostgresQuery, logger: Logger, file: String, line: Int) async throws -> PostgresRowSequence {
        let optionalLogger: Logger? = logger
        return try await self.query(query, logger: optionalLogger, file: file, line: line)
    }
}

// MARK: - Generated-style query helpers
//
// These mirror what QueryCodeGenerator now emits: each takes `some
// PostgresQueryRunner`, so the same function works against a pooled client or a
// transaction-scoped connection.

private enum TxItemsQueries {
    static func insertItem(_ db: some PostgresQueryRunner, id: UUID, label: String, logger: Logger, file: String = #fileID, line: Int = #line) async throws {
        try await db.query(
            "INSERT INTO qr_tx_items (id, label) VALUES (\(id), \(label))",
            logger: logger,
            file: file,
            line: line
        )
    }

    static func listLabels(_ db: some PostgresQueryRunner, logger: Logger, file: String = #fileID, line: Int = #line) async throws -> [String] {
        var results: [String] = []
        for try await label in try await db.query(
            "SELECT label FROM qr_tx_items ORDER BY label",
            logger: logger,
            file: file,
            line: line
        ).decode(String.self) {
            results.append(label)
        }
        return results
    }
}

// MARK: - Transaction Tests

private let postgresAvailable = ProcessInfo.processInfo.environment["PGHOST"] != nil

private let log: Logger = {
    var l = Logger(label: "postgres-models.tx-test")
    l.logLevel = .warning
    return l
}()

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

private struct RollbackSentinel: Error {}

@Suite("Transactions", .serialized)
struct TransactionTests {
    private func resetTable(_ client: PostgresClient) async throws {
        try await client.query(PostgresQuery(unsafeSQL: "DROP TABLE IF EXISTS qr_tx_items"), logger: log)
        try await client.query(
            PostgresQuery(unsafeSQL: "CREATE TABLE qr_tx_items (id UUID PRIMARY KEY, label TEXT NOT NULL)"),
            logger: log
        )
    }

    /// Multiple generated calls inside one `withTransaction` block commit together.
    @Test(.enabled(if: postgresAvailable))
    func multipleGeneratedQueriesCommitTogether() async throws {
        try await withClient { client in
            try await resetTable(client)

            try await client.withTransaction(logger: log) { connection in
                try await TxItemsQueries.insertItem(connection, id: UUID(), label: "alpha", logger: log)
                try await TxItemsQueries.insertItem(connection, id: UUID(), label: "beta", logger: log)
            }

            let labels = try await TxItemsQueries.listLabels(client, logger: log)
            #expect(labels == ["alpha", "beta"])
        }
    }

    /// If the transaction body throws after some generated calls, the whole
    /// transaction rolls back — proving the calls shared one connection.
    @Test(.enabled(if: postgresAvailable))
    func multipleGeneratedQueriesRollBackTogether() async throws {
        try await withClient { client in
            try await resetTable(client)

            var threw = false
            do {
                try await client.withTransaction(logger: log) { connection in
                    try await TxItemsQueries.insertItem(connection, id: UUID(), label: "alpha", logger: log)
                    try await TxItemsQueries.insertItem(connection, id: UUID(), label: "beta", logger: log)
                    throw RollbackSentinel()
                }
            } catch {
                threw = true
            }
            #expect(threw)

            // Nothing should have persisted.
            let labels = try await TxItemsQueries.listLabels(client, logger: log)
            #expect(labels.isEmpty)
        }
    }

    /// The same generated helper accepts a pooled client too (no transaction).
    @Test(.enabled(if: postgresAvailable))
    func generatedHelperAcceptsPooledClient() async throws {
        try await withClient { client in
            try await resetTable(client)
            try await TxItemsQueries.insertItem(client, id: UUID(), label: "solo", logger: log)
            let labels = try await TxItemsQueries.listLabels(client, logger: log)
            #expect(labels == ["solo"])
        }
    }
}
