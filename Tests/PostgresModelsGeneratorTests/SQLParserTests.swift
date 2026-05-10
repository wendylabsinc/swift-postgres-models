import Testing
@testable import PostgresModelsGeneratorCore

struct SQLParserTests {
    // MARK: parseQueryFile — happy paths

    @Test func parsesOneQuery() throws {
        let input = """
            -- @query GetUser :one
            -- @param id: UUID
            -- @returns id: UUID, name: String
            SELECT id, name FROM users WHERE id = $1;
            """
        let result = try SQLParser.parseQueryFile(input)
        #expect(result.queries.count == 1)
        let q = result.queries[0]
        #expect(q.name == "GetUser")
        #expect(q.kind == .one)
        #expect(q.params == [ParsedParam(name: "id", type: "UUID")])
        #expect(q.returns == [
            ParsedReturn(name: "id", type: "UUID"),
            ParsedReturn(name: "name", type: "String"),
        ])
        #expect(q.sql.contains("SELECT id, name FROM users WHERE id ="))
    }

    @Test func parsesManyQuery() throws {
        let input = """
            -- @query ListUsers :many
            -- @returns id: UUID, name: String
            SELECT id, name FROM users;
            """
        let result = try SQLParser.parseQueryFile(input)
        #expect(result.queries[0].kind == .many)
        #expect(result.queries[0].params.isEmpty)
    }

    @Test func parsesExecQuery() throws {
        let input = """
            -- @query DeleteUser :exec
            -- @param id: UUID
            DELETE FROM users WHERE id = $1;
            """
        let result = try SQLParser.parseQueryFile(input)
        #expect(result.queries[0].kind == .exec)
        #expect(result.queries[0].returns.isEmpty)
    }

    @Test func parsesMultipleQueriesInOneFile() throws {
        let input = """
            -- @query GetUser :one
            -- @param id: UUID
            -- @returns id: UUID
            SELECT id FROM users WHERE id = $1;

            -- @query ListUsers :many
            -- @returns id: UUID
            SELECT id FROM users;
            """
        let result = try SQLParser.parseQueryFile(input)
        #expect(result.queries.count == 2)
        #expect(result.queries[0].name == "GetUser")
        #expect(result.queries[1].name == "ListUsers")
    }

    @Test func parsesOptionalTypes() throws {
        let input = """
            -- @query GetUser :one
            -- @param id: UUID
            -- @returns id: UUID, email: String?
            SELECT id, email FROM users WHERE id = $1;
            """
        let result = try SQLParser.parseQueryFile(input)
        #expect(result.queries[0].returns[1].type == "String?")
    }

    @Test func emptyFileProducesEmptyResult() throws {
        let result = try SQLParser.parseQueryFile("")
        #expect(result.queries.isEmpty)
    }

    @Test func fileWithOnlyCommentsProducesEmptyResult() throws {
        let result = try SQLParser.parseQueryFile("-- just a comment\n-- another comment\n")
        #expect(result.queries.isEmpty)
    }

    // MARK: parseQueryFile — error cases

    @Test func throwsOnMissingKind() {
        let input = """
            -- @query GetUser
            -- @returns id: UUID
            SELECT id FROM users;
            """
        #expect(throws: SQLParserError.missingQueryKind(line: "-- @query GetUser")) {
            try SQLParser.parseQueryFile(input)
        }
    }

    @Test func throwsOnUnknownKind() {
        let input = """
            -- @query GetUser :fetch
            -- @returns id: UUID
            SELECT id FROM users;
            """
        #expect(throws: SQLParserError.unknownQueryKind("fetch")) {
            try SQLParser.parseQueryFile(input)
        }
    }

    @Test func throwsOnMissingReturnsForOne() {
        let input = """
            -- @query GetUser :one
            -- @param id: UUID
            SELECT id FROM users WHERE id = $1;
            """
        #expect(throws: SQLParserError.missingReturns(queryName: "GetUser")) {
            try SQLParser.parseQueryFile(input)
        }
    }

    @Test func throwsOnMissingReturnsForMany() {
        let input = """
            -- @query ListUsers :many
            SELECT id FROM users;
            """
        #expect(throws: SQLParserError.missingReturns(queryName: "ListUsers")) {
            try SQLParser.parseQueryFile(input)
        }
    }

    @Test func throwsOnUnsupportedParamType() {
        let input = """
            -- @query GetUser :one
            -- @param id: URL
            -- @returns id: UUID
            SELECT id FROM users WHERE id = $1;
            """
        #expect(throws: SQLParserError.unsupportedType("URL", queryName: "GetUser")) {
            try SQLParser.parseQueryFile(input)
        }
    }

    @Test func throwsOnUnsupportedReturnType() {
        let input = """
            -- @query GetUser :one
            -- @param id: UUID
            -- @returns id: Data
            SELECT id FROM users WHERE id = $1;
            """
        #expect(throws: SQLParserError.unsupportedType("Data", queryName: "GetUser")) {
            try SQLParser.parseQueryFile(input)
        }
    }

    @Test func throwsOnParamCountMismatch() {
        let input = """
            -- @query GetUser :one
            -- @param id: UUID
            -- @param name: String
            -- @returns id: UUID
            SELECT id FROM users WHERE id = $1;
            """
        #expect(throws: SQLParserError.paramCountMismatch(queryName: "GetUser", declared: 2, placeholders: 1)) {
            try SQLParser.parseQueryFile(input)
        }
    }

    @Test func throwsOnEmptySQLBody() {
        let input = """
            -- @query GetUser :one
            -- @param id: UUID
            -- @returns id: UUID
            """
        #expect(throws: SQLParserError.emptySQLBody(queryName: "GetUser")) {
            try SQLParser.parseQueryFile(input)
        }
    }

    @Test func throwsOnMultipleReturnsLines() {
        let input = """
            -- @query GetUser :one
            -- @param id: UUID
            -- @returns id: UUID
            -- @returns name: String
            SELECT id FROM users WHERE id = $1;
            """
        #expect(throws: SQLParserError.multipleReturnsLines(queryName: "GetUser")) {
            try SQLParser.parseQueryFile(input)
        }
    }

    @Test func throwsOnMalformedParam() {
        let input = """
            -- @query GetUser :one
            -- @param id
            -- @returns id: UUID
            SELECT id FROM users WHERE id = $1;
            """
        #expect(throws: SQLParserError.malformedAnnotation("id")) {
            try SQLParser.parseQueryFile(input)
        }
    }

    @Test func throwsOnSkippedPlaceholder() {
        let input = """
            -- @query GetUser :one
            -- @param id: UUID
            -- @param name: String
            -- @param email: String
            -- @returns id: UUID
            SELECT id FROM users WHERE id = $1 AND role = $3;
            """
        #expect(throws: (any Error).self) {
            try SQLParser.parseQueryFile(input)
        }
    }

    // MARK: parseMigrationFile

    @Test func parsesMigrationFile() {
        let m = SQLParser.parseMigrationFile(
            name: "001_create_users.migration.sql",
            contents: "CREATE TABLE users (id UUID PRIMARY KEY);\n"
        )
        #expect(m.name == "001_create_users.migration.sql")
        #expect(m.sql == "CREATE TABLE users (id UUID PRIMARY KEY);")
    }
}
