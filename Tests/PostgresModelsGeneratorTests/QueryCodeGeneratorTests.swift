import Testing
@testable import PostgresModelsGeneratorCore

struct QueryCodeGeneratorTests {
    // MARK: :one

    @Test func generatesOneQuerySignatureAndReturnType() {
        let file = ParsedQueryFile(queries: [
            ParsedQuery(
                name: "GetUser",
                kind: .one,
                params: [ParsedParam(name: "id", type: "UUID")],
                returns: [
                    ParsedReturn(name: "id", type: "UUID"),
                    ParsedReturn(name: "name", type: "String"),
                ],
                sql: "SELECT id, name FROM users WHERE id = $1"
            ),
        ])
        let output = QueryCodeGenerator.generate(from: file, structName: "UsersQueries")
        #expect(output.contains("struct UsersQueries {"))
        #expect(output.contains("static func getUser("))
        #expect(output.contains("_ client: PostgresClient,"))
        #expect(output.contains("id: UUID,"))
        #expect(output.contains("logger: Logger"))
        #expect(output.contains("async throws -> (id: UUID, name: String)?"))
        #expect(output.contains(#"rows.decode((UUID, String).self)"#))
        #expect(output.contains("return (id: id, name: name)"))
        #expect(output.contains("return nil"))
    }

    @Test func oneQuerySingleColumnReturnType() {
        let file = ParsedQueryFile(queries: [
            ParsedQuery(
                name: "GetUserID",
                kind: .one,
                params: [ParsedParam(name: "email", type: "String")],
                returns: [ParsedReturn(name: "id", type: "UUID")],
                sql: "SELECT id FROM users WHERE email = $1"
            ),
        ])
        let output = QueryCodeGenerator.generate(from: file, structName: "UsersQueries")
        #expect(output.contains("async throws -> UUID?"))
        #expect(output.contains("rows.decode(UUID.self)"))
        #expect(output.contains("return id"))
    }

    @Test func oneQuerySQLInterpolatesBindings() {
        let file = ParsedQueryFile(queries: [
            ParsedQuery(
                name: "GetUser",
                kind: .one,
                params: [ParsedParam(name: "id", type: "UUID")],
                returns: [ParsedReturn(name: "id", type: "UUID")],
                sql: "SELECT id FROM users WHERE id = $1"
            ),
        ])
        let output = QueryCodeGenerator.generate(from: file, structName: "UsersQueries")
        #expect(output.contains(#"WHERE id = \(id)"#))
    }

    // MARK: :many

    @Test func generatesManyQueryReturnType() {
        let file = ParsedQueryFile(queries: [
            ParsedQuery(
                name: "ListUsers",
                kind: .many,
                params: [],
                returns: [
                    ParsedReturn(name: "id", type: "UUID"),
                    ParsedReturn(name: "name", type: "String"),
                ],
                sql: "SELECT id, name FROM users"
            ),
        ])
        let output = QueryCodeGenerator.generate(from: file, structName: "UsersQueries")
        #expect(output.contains("async throws -> [(id: UUID, name: String)]"))
        #expect(output.contains("var results: [(id: UUID, name: String)] = []"))
        #expect(output.contains("results.append((id: id, name: name))"))
        #expect(output.contains("return results"))
    }

    // MARK: :exec

    @Test func generatesExecQueryNoReturnType() {
        let file = ParsedQueryFile(queries: [
            ParsedQuery(
                name: "DeleteUser",
                kind: .exec,
                params: [ParsedParam(name: "id", type: "UUID")],
                returns: [],
                sql: "DELETE FROM users WHERE id = $1"
            ),
        ])
        let output = QueryCodeGenerator.generate(from: file, structName: "UsersQueries")
        #expect(output.contains("async throws {"))
        #expect(!output.contains("->"))
        #expect(output.contains("try await client.query("))
    }

    // MARK: SQL binding

    @Test func twoParamsProducesTwoBindings() {
        let file = ParsedQueryFile(queries: [
            ParsedQuery(
                name: "CreateUser",
                kind: .exec,
                params: [
                    ParsedParam(name: "id", type: "UUID"),
                    ParsedParam(name: "name", type: "String"),
                ],
                returns: [],
                sql: "INSERT INTO users (id, name) VALUES ($1, $2)"
            ),
        ])
        let output = QueryCodeGenerator.generate(from: file, structName: "UsersQueries")
        #expect(output.contains(#"VALUES (\(id), \(name))"#))
    }

    @Test func snakeCaseParamConvertedToCamelCase() {
        let file = ParsedQueryFile(queries: [
            ParsedQuery(
                name: "GetUser",
                kind: .one,
                params: [ParsedParam(name: "user_id", type: "UUID")],
                returns: [ParsedReturn(name: "id", type: "UUID")],
                sql: "SELECT id FROM users WHERE id = $1"
            ),
        ])
        let output = QueryCodeGenerator.generate(from: file, structName: "UsersQueries")
        #expect(output.contains("userId: UUID,"))
        #expect(output.contains(#"WHERE id = \(userId)"#))
    }

    // MARK: Headers and structure

    @Test func outputContainsRequiredImports() {
        let file = ParsedQueryFile(queries: [])
        let output = QueryCodeGenerator.generate(from: file, structName: "EmptyQueries")
        #expect(output.contains("#if canImport(FoundationEssentials)\nimport FoundationEssentials\n#else\nimport Foundation\n#endif"))
        #expect(output.contains("import Logging"))
        #expect(output.contains("import PostgresNIO"))
    }

    @Test func emptyFileGeneratesEmptyStruct() {
        let file = ParsedQueryFile(queries: [])
        let output = QueryCodeGenerator.generate(from: file, structName: "EmptyQueries")
        #expect(output.contains("struct EmptyQueries {"))
        #expect(output.hasSuffix("}"))
    }

    @Test func multipleQueriesAllPresent() {
        let file = ParsedQueryFile(queries: [
            ParsedQuery(
                name: "GetUser", kind: .one,
                params: [ParsedParam(name: "id", type: "UUID")],
                returns: [ParsedReturn(name: "id", type: "UUID")],
                sql: "SELECT id FROM users WHERE id = $1"
            ),
            ParsedQuery(
                name: "ListUsers", kind: .many,
                params: [],
                returns: [ParsedReturn(name: "id", type: "UUID")],
                sql: "SELECT id FROM users"
            ),
        ])
        let output = QueryCodeGenerator.generate(from: file, structName: "UsersQueries")
        #expect(output.contains("static func getUser("))
        #expect(output.contains("static func listUsers("))
    }

    // MARK: Semicolon stripping

    @Test func trailingSemicolonRemovedFromSQL() {
        let file = ParsedQueryFile(queries: [
            ParsedQuery(
                name: "DeleteAll", kind: .exec,
                params: [],
                returns: [],
                sql: "DELETE FROM users;"
            ),
        ])
        let output = QueryCodeGenerator.generate(from: file, structName: "UsersQueries")
        #expect(!output.contains("DELETE FROM users;\","))
        #expect(output.contains("DELETE FROM users\","))
    }

    // MARK: 11+ params

    @Test func elevenParamsProducesCorrectBindings() {
        let params = (1...11).map { ParsedParam(name: "p\($0)", type: "String") }
        let placeholders = (1...11).map { "$\($0)" }.joined(separator: ", ")
        let file = ParsedQueryFile(queries: [
            ParsedQuery(
                name: "BigQuery", kind: .exec,
                params: params,
                returns: [],
                sql: "INSERT INTO t VALUES (\(placeholders))"
            ),
        ])
        let output = QueryCodeGenerator.generate(from: file, structName: "TQueries")
        #expect(output.contains(#"VALUES (\(p1), \(p2), \(p3), \(p4), \(p5), \(p6), \(p7), \(p8), \(p9), \(p10), \(p11))"#))
        #expect(!output.contains(#"\(p1)0"#))
        #expect(!output.contains(#"\(p1)1"#))
    }

    // MARK: SQL escaping

    @Test func sqlWithQuotedIdentifierIsEscaped() {
        let file = ParsedQueryFile(queries: [
            ParsedQuery(
                name: "GetUser", kind: .exec,
                params: [],
                returns: [],
                sql: #"SELECT "id" FROM "users""#
            ),
        ])
        let output = QueryCodeGenerator.generate(from: file, structName: "UsersQueries")
        #expect(output.contains(#"SELECT \"id\" FROM \"users\""#))
    }

    @Test func sqlWithBackslashIsEscaped() {
        let file = ParsedQueryFile(queries: [
            ParsedQuery(
                name: "SearchUser", kind: .exec,
                params: [ParsedParam(name: "q", type: "String")],
                returns: [],
                sql: #"SELECT id FROM users WHERE name LIKE $1 ESCAPE '\'"#
            ),
        ])
        let output = QueryCodeGenerator.generate(from: file, structName: "UsersQueries")
        #expect(output.contains(#"ESCAPE '\\'"#))
    }
}
