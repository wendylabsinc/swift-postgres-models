import Testing
@testable import PostgresModelsSchema

struct CatalogBuilderEnumTests {
    @Test func extractsEnumValues() throws {
        let c = try CatalogBuilder().build(fromDDL: "CREATE TYPE mood AS ENUM ('happy', 'sad', 'ok');")
        #expect(c.enums["mood"] == ["happy", "sad", "ok"])
    }
}
