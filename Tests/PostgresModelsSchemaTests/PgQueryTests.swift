import Testing
@testable import PostgresModelsSchema

struct PgQueryTests {
    @Test func parsesSelectAndNavigatesTree() throws {
        let tree = try PgQuery.parse("SELECT 1")
        let stmts = tree["stmts"]?.arrayValue
        #expect(stmts?.isEmpty == false)
        // stmts[0].stmt is an object keyed by the node type
        let stmt = stmts?[0]["stmt"]?.objectValue
        #expect(stmt?.keys.contains("SelectStmt") == true)
    }

    @Test func throwsOnSyntaxError() {
        #expect(throws: PgQueryError.self) {
            _ = try PgQuery.parse("SELEC 1")
        }
    }

    @Test func decodesScalars() throws {
        let v = try JSONValue.decode(from: #"{"a": 1, "b": "x", "c": true, "d": null, "e": [1,2]}"#)
        #expect(v["a"]?.numberValue == 1)
        #expect(v["b"]?.stringValue == "x")
        #expect(v["c"] == .bool(true))
        #expect(v["d"] == JSONValue.null)
        #expect(v["e"]?.arrayValue?.count == 2)
    }
}
