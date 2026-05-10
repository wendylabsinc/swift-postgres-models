import Testing
@testable import PostgresModelsGeneratorCore

struct MigrationCodeGeneratorTests {
    @Test func generatesRequiredImports() {
        let output = MigrationCodeGenerator.generate(from: [])
        #expect(output.contains("import Logging"))
        #expect(output.contains("import PostgresNIO"))
    }

    @Test func generatesStructWithEmptyAll() {
        let output = MigrationCodeGenerator.generate(from: [])
        #expect(output.contains("struct Migrations {"))
        #expect(output.contains("private static let all: [(String, String)] = []"))
    }

    @Test func embedsMigrationNameAndSQL() {
        let migrations = [
            ParsedMigrationFile(
                name: "001_create_users.migration.sql",
                sql: "CREATE TABLE users (id UUID PRIMARY KEY)"
            ),
        ]
        let output = MigrationCodeGenerator.generate(from: migrations)
        #expect(output.contains("001_create_users.migration.sql"))
        #expect(output.contains("CREATE TABLE users (id UUID PRIMARY KEY)"))
    }

    @Test func embedsBothMigrationsInOrder() {
        let migrations = [
            ParsedMigrationFile(name: "001_create_users.migration.sql", sql: "CREATE TABLE users (id UUID)"),
            ParsedMigrationFile(name: "002_add_index.migration.sql",    sql: "CREATE INDEX users_idx ON users (id)"),
        ]
        let output = MigrationCodeGenerator.generate(from: migrations)
        let pos1 = output.range(of: "001_create_users")!.lowerBound
        let pos2 = output.range(of: "002_add_index")!.lowerBound
        #expect(pos1 < pos2)
    }

    @Test func generatesRunFunction() {
        let output = MigrationCodeGenerator.generate(from: [])
        #expect(output.contains("static func run(client: PostgresClient, logger: Logger) async throws"))
        #expect(output.contains("postgres_models_migrations"))
        #expect(output.contains("for (name, sql) in all {"))
    }

    @Test func runFunctionUsesTransaction() {
        let output = MigrationCodeGenerator.generate(from: [])
        #expect(output.contains("BEGIN"))
        #expect(output.contains("COMMIT"))
        #expect(output.contains("ROLLBACK"))
    }

    @Test func migrationSQLWithBackslashIsEscaped() {
        let migrations = [
            ParsedMigrationFile(
                name: "001_test.migration.sql",
                sql: #"CREATE INDEX idx ON t WHERE col ~ E'foo\nbar'"#
            ),
        ]
        let output = MigrationCodeGenerator.generate(from: migrations)
        #expect(output.contains(#"WHERE col ~ E'foo\\nbar'"#))
    }
}
