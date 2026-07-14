/// Helpers for reading libpg_query's JSON parse tree.
enum ParseTreeExtract {
    /// The list of statement nodes: tree["stmts"][i]["stmt"] -> { "<NodeType>": {...} }.
    static func statementNodes(_ tree: JSONValue) -> [(type: String, body: JSONValue)] {
        guard let stmts = tree["stmts"]?.arrayValue else { return [] }
        return stmts.compactMap { wrapper in
            guard let stmt = wrapper["stmt"]?.objectValue,
                  let (type, body) = stmt.first
            else { return nil }
            return (type, body)
        }
    }

    /// Canonical type name = last element of typeName.names[].String.sval; arrayBounds -> isArray.
    static func pgType(from typeNameNode: JSONValue) -> PGType {
        let names = typeNameNode["names"]?.arrayValue ?? []
        let last = names.compactMap { $0["String"]?["sval"]?.stringValue }.last ?? "unknown"
        let isArray = typeNameNode["arrayBounds"]?.arrayValue?.isEmpty == false
        return PGType(name: last, isArray: isArray)
    }

    /// Builds a Column from a ColumnDef body. Returns nil if it lacks a name/type.
    static func column(fromColumnDef def: JSONValue) -> Column? {
        guard let name = def["colname"]?.stringValue,
              let typeNode = def["typeName"]
        else { return nil }

        var isNullable = true
        var isPrimaryKey = false
        var hasDefault = false
        for c in def["constraints"]?.arrayValue ?? [] {
            guard let contype = c["Constraint"]?["contype"]?.stringValue else { continue }
            switch contype {
            case "CONSTR_NOTNULL": isNullable = false
            case "CONSTR_PRIMARY": isPrimaryKey = true; isNullable = false
            case "CONSTR_DEFAULT": hasDefault = true
            default: break
            }
        }
        return Column(name: name, type: pgType(from: typeNode),
                      isNullable: isNullable, isPrimaryKey: isPrimaryKey, hasDefault: hasDefault)
    }

    /// Column names named by a table-level PRIMARY KEY constraint node, if any.
    static func tableLevelPrimaryKeyColumns(fromConstraint node: JSONValue) -> [String]? {
        guard node["contype"]?.stringValue == "CONSTR_PRIMARY" else { return nil }
        return node["keys"]?.arrayValue?.compactMap { $0["String"]?["sval"]?.stringValue }
    }
}
