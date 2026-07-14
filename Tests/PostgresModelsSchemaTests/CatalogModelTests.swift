import Testing
@testable import PostgresModelsSchema

struct CatalogModelTests {
    @Test func upsertAndLookup() {
        var catalog = Catalog()
        let table = Table(name: "users", columns: [
            Column(name: "id", type: PGType(name: "uuid"), isNullable: false, isPrimaryKey: true, hasDefault: false),
            Column(name: "email", type: PGType(name: "text"), isNullable: true, isPrimaryKey: false, hasDefault: false),
        ])
        catalog.upsert(table)
        #expect(catalog.tables["users"]?.columns.count == 2)
        #expect(catalog.tables["users"]?.column(named: "email")?.isNullable == true)
        #expect(catalog.tables["users"]?.column(named: "missing") == nil)
    }

    @Test func removeAndEnum() {
        var catalog = Catalog()
        catalog.upsert(Table(name: "t", columns: []))
        catalog.removeTable("t")
        #expect(catalog.tables["t"] == nil)
        catalog.defineEnum(name: "mood", values: ["happy", "sad"])
        #expect(catalog.enums["mood"] == ["happy", "sad"])
    }
}
