public struct CatalogBuilder {
    public init() {}

    public func build(fromDDL ddl: String) throws -> Catalog {
        try build(fromMigrations: [(name: "<ddl>", sql: ddl)])
    }

    public func build(fromMigrations migrations: [(name: String, sql: String)]) throws -> Catalog {
        var catalog = Catalog()
        for migration in migrations {
            let tree: JSONValue
            do {
                tree = try PgQuery.parse(migration.sql)
            } catch let error as PgQueryError {
                throw CatalogBuildError(migration: migration.name, message: error.message)
            }
            for (type, body) in ParseTreeExtract.statementNodes(tree) {
                apply(type: type, body: body, into: &catalog)
            }
        }
        return catalog
    }

    private func apply(type: String, body: JSONValue, into catalog: inout Catalog) {
        switch type {
        case "CreateStmt":     applyCreateTable(body, into: &catalog)
        case "AlterTableStmt": applyAlterTable(body, into: &catalog)
        case "CreateEnumStmt": applyCreateEnum(body, into: &catalog)
        default:               break   // other statements handled in later tasks; ignored here
        }
    }

    func applyCreateTable(_ body: JSONValue, into catalog: inout Catalog) {
        guard let name = body["relation"]?["relname"]?.stringValue else { return }
        var columns: [Column] = []
        var pkColumns: Set<String> = []

        for elt in body["tableElts"]?.arrayValue ?? [] {
            if let def = elt["ColumnDef"], let column = ParseTreeExtract.column(fromColumnDef: def) {
                columns.append(column)
            } else if let constraint = elt["Constraint"],
                      let keys = ParseTreeExtract.tableLevelPrimaryKeyColumns(fromConstraint: constraint) {
                pkColumns.formUnion(keys)
            }
        }

        // Apply table-level PK to the named columns.
        columns = columns.map { col in
            guard pkColumns.contains(col.name) else { return col }
            var c = col
            c.isPrimaryKey = true
            c.isNullable = false
            return c
        }

        catalog.upsert(Table(name: name, columns: columns))
    }

    func applyAlterTable(_ body: JSONValue, into catalog: inout Catalog) {
        guard let tableName = body["relation"]?["relname"]?.stringValue,
              var table = catalog.tables[tableName] else { return }

        for cmdWrapper in body["cmds"]?.arrayValue ?? [] {
            guard let cmd = cmdWrapper["AlterTableCmd"] else { continue }
            let subtype = cmd["subtype"]?.stringValue

            switch subtype {
            case "AT_AddColumn":
                if let def = cmd["def"]?["ColumnDef"],
                   let column = ParseTreeExtract.column(fromColumnDef: def) {
                    table.columns.append(column)
                }
            case "AT_DropColumn":
                if let name = cmd["name"]?.stringValue {
                    table.columns.removeAll { $0.name == name }
                }
            case "AT_AlterColumnType":
                if let name = cmd["name"]?.stringValue,
                   let typeNode = cmd["def"]?["ColumnDef"]?["typeName"],
                   let idx = table.columns.firstIndex(where: { $0.name == name }) {
                    table.columns[idx].type = ParseTreeExtract.pgType(from: typeNode)
                }
            case "AT_SetNotNull":
                if let name = cmd["name"]?.stringValue,
                   let idx = table.columns.firstIndex(where: { $0.name == name }) {
                    table.columns[idx].isNullable = false
                }
            case "AT_DropNotNull":
                if let name = cmd["name"]?.stringValue,
                   let idx = table.columns.firstIndex(where: { $0.name == name }) {
                    table.columns[idx].isNullable = true
                }
            default:
                break
            }
        }

        catalog.upsert(table)
    }

    func applyCreateEnum(_ body: JSONValue, into catalog: inout Catalog) {
        // typeName is a list of String nodes; the last is the enum's name.
        let nameParts = body["typeName"]?.arrayValue?.compactMap { $0["String"]?["sval"]?.stringValue } ?? []
        guard let name = nameParts.last else { return }
        let values = body["vals"]?.arrayValue?.compactMap { $0["String"]?["sval"]?.stringValue } ?? []
        catalog.defineEnum(name: name, values: values)
    }
}
