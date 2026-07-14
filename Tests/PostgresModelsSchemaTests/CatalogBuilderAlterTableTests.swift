import Testing
@testable import PostgresModelsSchema

struct CatalogBuilderAlterTableTests {
    private func catalog(_ ddl: String) throws -> Catalog { try CatalogBuilder().build(fromDDL: ddl) }

    @Test func addColumn() throws {
        let c = try catalog("""
            CREATE TABLE t (id int4);
            ALTER TABLE t ADD COLUMN name text NOT NULL;
            """)
        #expect(c.tables["t"]?.columns.map(\.name) == ["id", "name"])
        #expect(c.tables["t"]?.column(named: "name")?.isNullable == false)
    }

    @Test func dropColumn() throws {
        let c = try catalog("""
            CREATE TABLE t (id int4, gone text);
            ALTER TABLE t DROP COLUMN gone;
            """)
        #expect(c.tables["t"]?.columns.map(\.name) == ["id"])
    }

    @Test func alterColumnTypeAndNullability() throws {
        let c = try catalog("""
            CREATE TABLE t (a int4);
            ALTER TABLE t ALTER COLUMN a TYPE int8;
            ALTER TABLE t ALTER COLUMN a SET NOT NULL;
            """)
        #expect(c.tables["t"]?.column(named: "a")?.type == PGType(name: "int8"))
        #expect(c.tables["t"]?.column(named: "a")?.isNullable == false)
    }

    @Test func dropNotNull() throws {
        let c = try catalog("""
            CREATE TABLE t (a int4 NOT NULL);
            ALTER TABLE t ALTER COLUMN a DROP NOT NULL;
            """)
        #expect(c.tables["t"]?.column(named: "a")?.isNullable == true)
    }
}
