import Testing
@testable import PostgresModelsSchema

struct CatalogBuilderMigrationsTests {
    @Test func laterMigrationAltersEarlierTable() throws {
        let migrations = [
            (name: "001_create.sql", sql: "CREATE TABLE t (id int4);"),
            (name: "002_add.sql",    sql: "ALTER TABLE t ADD COLUMN name text NOT NULL;"),
        ]
        let c = try CatalogBuilder().build(fromMigrations: migrations)
        #expect(c.tables["t"]?.columns.map(\.name) == ["id", "name"])
        #expect(c.tables["t"]?.column(named: "name")?.isNullable == false)
    }

    @Test func orderIsRespected() throws {
        // Applying the ALTER before the CREATE must NOT populate the column
        // (the ALTER targets a not-yet-existent table and is a no-op).
        let migrations = [
            (name: "a.sql", sql: "ALTER TABLE t ADD COLUMN name text;"),
            (name: "b.sql", sql: "CREATE TABLE t (id int4);"),
        ]
        let c = try CatalogBuilder().build(fromMigrations: migrations)
        #expect(c.tables["t"]?.columns.map(\.name) == ["id"])
    }

    @Test func parseErrorIsAttributedToFailingMigration() {
        let migrations = [
            (name: "001_create.sql", sql: "CREATE TABLE t (id int4);"),
            (name: "002_bad.sql",    sql: "CREATE TABLE (garbage"),
        ]
        #expect(throws: CatalogBuildError.self) {
            do {
                _ = try CatalogBuilder().build(fromMigrations: migrations)
            } catch let error as CatalogBuildError {
                #expect(error.migration == "002_bad.sql")
                throw error
            }
        }
    }
}
