public struct SQLParser {
    static let supportedTypes: Set<String> = [
        "UUID", "String", "Int", "Double", "Bool", "Date",
        "UUID?", "String?", "Int?", "Double?", "Bool?", "Date?",
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
        let type = s[s.index(after: idx)...].trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !type.isEmpty else {
            throw SQLParserError.malformedAnnotation(s)
        }
        return (name, type)
    }

    private static func parseReturnsList(_ s: String, queryName: String) throws -> [ParsedReturn] {
        // Split on "," — safe because Swift types don't contain commas
        try s.components(separatedBy: ",").map { item in
            let (name, type) = try parseNameType(item.trimmingCharacters(in: .whitespaces), queryName: queryName)
            return ParsedReturn(name: name, type: type)
        }
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
