public struct PGType: Equatable, Sendable {
    public var name: String
    public var isArray: Bool
    public init(name: String, isArray: Bool = false) {
        self.name = name
        self.isArray = isArray
    }
}

public struct Column: Equatable, Sendable {
    public var name: String
    public var type: PGType
    public var isNullable: Bool
    public var isPrimaryKey: Bool
    public var hasDefault: Bool
    public init(name: String, type: PGType, isNullable: Bool, isPrimaryKey: Bool, hasDefault: Bool) {
        self.name = name
        self.type = type
        self.isNullable = isNullable
        self.isPrimaryKey = isPrimaryKey
        self.hasDefault = hasDefault
    }
}

public struct Table: Equatable, Sendable {
    public var name: String
    public var columns: [Column]
    public init(name: String, columns: [Column]) {
        self.name = name
        self.columns = columns
    }
    public func column(named name: String) -> Column? {
        columns.first { $0.name == name }
    }
}

public struct Catalog: Equatable, Sendable {
    public private(set) var tables: [String: Table]
    public private(set) var enums: [String: [String]]
    public init() {
        tables = [:]
        enums = [:]
    }
    public mutating func upsert(_ table: Table) { tables[table.name] = table }
    public mutating func removeTable(_ name: String) { tables[name] = nil }
    public mutating func defineEnum(name: String, values: [String]) { enums[name] = values }
}
