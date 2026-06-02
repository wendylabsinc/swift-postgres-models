public struct SQLParser {
    static let typeAliases: [String: String] = [
        // Arrays
        "TEXT[]": "[String]",    "TEXT[]?": "[String]?",
        // Network types
        "INET": "String",        "INET?": "String?",
        "MACADDR": "String",     "MACADDR?": "String?",
        // JSON types
        "JSON": "String",        "JSON?": "String?",
        "JSONB": "String",       "JSONB?": "String?",
        // 64-bit integer types
        "BIGINT": "Int64",       "BIGINT?": "Int64?",
        "BIGSERIAL": "Int64",    "BIGSERIAL?": "Int64?",
        "INT8": "Int64",         "INT8?": "Int64?",
        // 32-bit integer types
        "INTEGER": "Int",        "INTEGER?": "Int?",
        "INT": "Int",            "INT?": "Int?",
        "INT4": "Int",           "INT4?": "Int?",
        "SERIAL": "Int",         "SERIAL?": "Int?",
        "SMALLINT": "Int",       "SMALLINT?": "Int?",
        "INT2": "Int",           "INT2?": "Int?",
        // Decimal / numeric types (parameterized forms handled via normalization)
        "NUMERIC": "Decimal",    "NUMERIC?": "Decimal?",
        "DECIMAL": "Decimal",    "DECIMAL?": "Decimal?",
        // Floating-point types
        "FLOAT8": "Double",      "FLOAT8?": "Double?",
        "FLOAT4": "Double",      "FLOAT4?": "Double?",
        "REAL": "Double",        "REAL?": "Double?",
        // String types
        "VARCHAR": "String",     "VARCHAR?": "String?",
        "CHAR": "String",        "CHAR?": "String?",
        "CHARACTER VARYING": "String", "CHARACTER VARYING?": "String?",
        // Boolean
        "BOOLEAN": "Bool",       "BOOLEAN?": "Bool?",
        // Timestamp types
        "TIMESTAMP": "Date",     "TIMESTAMP?": "Date?",
        "TIMESTAMPTZ": "Date",   "TIMESTAMPTZ?": "Date?",
        "TIMESTAMP WITH TIME ZONE": "Date", "TIMESTAMP WITH TIME ZONE?": "Date?",
    ]

    static let supportedTypes: Set<String> = [
        "UUID", "String", "Int", "Int64", "Double", "Decimal", "Bool", "Date",
        "UUID?", "String?", "Int?", "Int64?", "Double?", "Decimal?", "Bool?", "Date?",
        "[String]", "[String]?",
    ]

    public static func parseQueryFile(_ contents: String) throws -> ParsedQueryFile {
        var queries: [ParsedQuery] = []
        let lines = contents.components(separatedBy: "\n")
        var i = 0

        while i < lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("-- @query ") else { i += 1; continue }

            let rest = String(trimmed.dropFirst("-- @query ".count))
            let parts = rest.components(separatedBy: " ").filter { !$0.isEmpty }
            guard parts.count >= 1 else { i += 1; continue }
            let queryName = parts[0]

            guard parts.count >= 2 else {
                throw SQLParserError.missingQueryKind(line: trimmed)
            }
            let kindRaw = parts[1].hasPrefix(":") ? String(parts[1].dropFirst()) : parts[1]
            guard let kind = QueryKind(rawValue: kindRaw) else {
                throw SQLParserError.unknownQueryKind(kindRaw)
            }

            i += 1
            var params: [ParsedParam] = []
            var returnsLine: String? = nil
            var sqlLines: [String] = []

            while i < lines.count {
                let l = lines[i].trimmingCharacters(in: .whitespaces)
                if l.hasPrefix("-- @query ") { break }
                if l.hasPrefix("-- @param ") {
                    let s = String(l.dropFirst("-- @param ".count))
                    let (name, type) = try parseNameType(s, queryName: queryName)
                    params.append(ParsedParam(name: name, type: type))
                    i += 1
                } else if l.hasPrefix("-- @returns ") {
                    guard returnsLine == nil else {
                        throw SQLParserError.multipleReturnsLines(queryName: queryName)
                    }
                    returnsLine = String(l.dropFirst("-- @returns ".count))
                    i += 1
                } else if l.hasPrefix("--") || l.isEmpty {
                    i += 1
                } else {
                    sqlLines.append(lines[i])
                    i += 1
                }
            }

            let sql = sqlLines
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespaces)
            guard !sql.isEmpty else {
                throw SQLParserError.emptySQLBody(queryName: queryName)
            }

            if kind == .one || kind == .many {
                guard returnsLine != nil else {
                    throw SQLParserError.missingReturns(queryName: queryName)
                }
            }

            let returns: [ParsedReturn] = try returnsLine.map { try parseReturnsList($0, queryName: queryName) } ?? []

            for p in params {
                guard supportedTypes.contains(p.type) else {
                    throw SQLParserError.unsupportedType(p.type, queryName: queryName)
                }
            }
            for r in returns {
                guard supportedTypes.contains(r.type) else {
                    throw SQLParserError.unsupportedType(r.type, queryName: queryName)
                }
            }

            let indices = placeholderIndices(in: sql)
            let expected = params.isEmpty ? Set<Int>() : Set(1...params.count)
            guard indices == expected else {
                let placeholderCount = indices.max() ?? 0
                throw SQLParserError.paramCountMismatch(
                    queryName: queryName,
                    declared: params.count,
                    placeholders: placeholderCount
                )
            }

            queries.append(ParsedQuery(name: queryName, kind: kind, params: params, returns: returns, sql: sql))
        }

        return ParsedQueryFile(queries: queries)
    }

    public static func parseMigrationFile(name: String, contents: String) -> ParsedMigrationFile {
        ParsedMigrationFile(name: name, sql: contents.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    // MARK: - Private helpers

    private static func parseNameType(_ s: String, queryName: String) throws -> (String, String) {
        let colonIdx = s.firstIndex(of: ":")
        guard let idx = colonIdx else {
            throw SQLParserError.malformedAnnotation(s)
        }
        let name = s[s.startIndex..<idx].trimmingCharacters(in: .whitespaces)
        let rawType = s[s.index(after: idx)...].trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !rawType.isEmpty else {
            throw SQLParserError.malformedAnnotation(s)
        }
        let normalizedType = normalizeSQLTypeName(rawType)
        let type = typeAliases[normalizedType] ?? normalizedType
        return (name, type)
    }

    private static func parseReturnsList(_ s: String, queryName: String) throws -> [ParsedReturn] {
        try splitTopLevelCommas(s).map { item in
            let (name, type) = try parseNameType(item.trimmingCharacters(in: .whitespaces), queryName: queryName)
            return ParsedReturn(name: name, type: type)
        }
    }

    /// Splits `s` on commas that are not inside parentheses, e.g. `NUMERIC(10,2)` stays intact.
    private static func splitTopLevelCommas(_ s: String) -> [String] {
        var result: [String] = []
        var depth = 0
        var current = ""
        for ch in s {
            if ch == "(" { depth += 1; current.append(ch) }
            else if ch == ")" { depth -= 1; current.append(ch) }
            else if ch == "," && depth == 0 { result.append(current); current = "" }
            else { current.append(ch) }
        }
        result.append(current)
        return result
    }

    /// Strips precision/scale modifiers from SQL type names, e.g. `NUMERIC(10,2)` → `NUMERIC`, `VARCHAR(255)?` → `VARCHAR?`.
    private static func normalizeSQLTypeName(_ raw: String) -> String {
        guard let parenStart = raw.firstIndex(of: "("),
              let parenEnd = raw.lastIndex(of: ")") else {
            return raw
        }
        return String(raw[raw.startIndex..<parenStart]) + String(raw[raw.index(after: parenEnd)...])
    }

    /// Returns the set of all `$N` placeholder indices found in `sql`.
    private static func placeholderIndices(in sql: String) -> Set<Int> {
        var indices: Set<Int> = []
        var idx = sql.startIndex
        while idx < sql.endIndex {
            if sql[idx] == "$" {
                let next = sql.index(after: idx)
                if next < sql.endIndex, sql[next].isNumber {
                    var numStr = ""
                    var j = next
                    while j < sql.endIndex, sql[j].isNumber {
                        numStr.append(sql[j])
                        j = sql.index(after: j)
                    }
                    if let n = Int(numStr) { indices.insert(n) }
                    idx = j
                    continue
                }
            }
            idx = sql.index(after: idx)
        }
        return indices
    }
}
