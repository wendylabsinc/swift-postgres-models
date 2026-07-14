public struct CatalogBuildError: Error, Equatable {
    public let migration: String
    public let message: String

    public init(migration: String, message: String) {
        self.migration = migration
        self.message = message
    }
}
