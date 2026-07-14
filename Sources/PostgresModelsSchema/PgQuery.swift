import CPgQuery

public struct PgQueryError: Error, Equatable {
    public let message: String
    public init(message: String) { self.message = message }
}

public enum PgQuery {
    /// Parses SQL via libpg_query and returns the parse tree as a `JSONValue`.
    public static func parse(_ sql: String) throws -> JSONValue {
        let result = pg_query_parse(sql)
        defer { pg_query_free_parse_result(result) }

        if let error = result.error {
            throw PgQueryError(message: String(cString: error.pointee.message))
        }
        guard let treePtr = result.parse_tree else {
            throw PgQueryError(message: "libpg_query returned no parse tree")
        }
        return try JSONValue.decode(from: String(cString: treePtr))
    }
}
