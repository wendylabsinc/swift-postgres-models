import Testing
@testable import PostgresModelsSchema

struct CatalogBuilderCreateTableTests {
    @Test func extractsColumnsTypesAndConstraints() throws {
        let ddl = """
            CREATE TABLE users (
                id    uuid PRIMARY KEY,
                name  text NOT NULL,
                email text,
                tags  text[]
            );
            """
        let catalog = try CatalogBuilder().build(fromDDL: ddl)
        let users = try #require(catalog.tables["users"])
        #expect(users.columns.map(\.name) == ["id", "name", "email", "tags"])

        let id = try #require(users.column(named: "id"))
        #expect(id.type == PGType(name: "uuid"))
        #expect(id.isPrimaryKey == true)
        #expect(id.isNullable == false)          // PK implies NOT NULL

        #expect(users.column(named: "name")?.isNullable == false)
        #expect(users.column(named: "email")?.isNullable == true)
        #expect(users.column(named: "tags")?.type == PGType(name: "text", isArray: true))
    }

    @Test func tableLevelPrimaryKey() throws {
        let ddl = "CREATE TABLE t (a int4, b int4, PRIMARY KEY (a));"
        let catalog = try CatalogBuilder().build(fromDDL: ddl)
        #expect(catalog.tables["t"]?.column(named: "a")?.isPrimaryKey == true)
        #expect(catalog.tables["t"]?.column(named: "a")?.isNullable == false)
        #expect(catalog.tables["t"]?.column(named: "b")?.isPrimaryKey == false)
    }

    @Test func defaultMarksHasDefault() throws {
        let ddl = "CREATE TABLE t (a int4 DEFAULT 0);"
        let catalog = try CatalogBuilder().build(fromDDL: ddl)
        #expect(catalog.tables["t"]?.column(named: "a")?.hasDefault == true)
    }
}
