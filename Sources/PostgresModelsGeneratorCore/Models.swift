public enum QueryKind: String, Equatable, Sendable {
    case one, many, exec
}

public struct ParsedParam: Equatable, Sendable {
    public let name: String
    public let type: String

    public init(name: String, type: String) {
        self.name = name
        self.type = type
    }
}

public struct ParsedReturn: Equatable, Sendable {
    public let name: String
    public let type: String

    public init(name: String, type: String) {
        self.name = name
        self.type = type
    }
}

public struct ParsedQuery: Equatable, Sendable {
    public let name: String
    public let kind: QueryKind
    public let params: [ParsedParam]
    public let returns: [ParsedReturn]
    public let sql: String

    public init(name: String, kind: QueryKind, params: [ParsedParam], returns: [ParsedReturn], sql: String) {
        self.name = name
        self.kind = kind
        self.params = params
        self.returns = returns
        self.sql = sql
    }
}

public struct ParsedQueryFile: Equatable, Sendable {
    public let queries: [ParsedQuery]

    public init(queries: [ParsedQuery]) {
        self.queries = queries
    }
}

public struct ParsedMigrationFile: Equatable, Sendable {
    public let name: String
    public let sql: String

    public init(name: String, sql: String) {
        self.name = name
        self.sql = sql
    }
}

public enum SQLParserError: Error, Equatable, Sendable {
    case missingQueryKind(line: String)
    case unknownQueryKind(String)
    case missingReturns(queryName: String)
    case multipleReturnsLines(queryName: String)
    case emptySQLBody(queryName: String)
    case unsupportedType(String, queryName: String)
    case paramCountMismatch(queryName: String, declared: Int, placeholders: Int)
    case malformedAnnotation(String)
}
