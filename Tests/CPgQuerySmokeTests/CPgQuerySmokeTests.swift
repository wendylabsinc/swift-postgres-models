import Testing
import CPgQuery

struct CPgQuerySmokeTests {
    @Test func parsesTrivialSelectIntoJSON() {
        var result = pg_query_parse("SELECT 1")
        defer { pg_query_free_parse_result(result) }
        #expect(result.error == nil)
        let json = result.parse_tree.map { String(cString: $0) } ?? ""
        #expect(json.contains("SelectStmt"))
    }

    @Test func reportsSyntaxError() {
        var result = pg_query_parse("SELEC 1")
        defer { pg_query_free_parse_result(result) }
        #expect(result.error != nil)
    }
}
