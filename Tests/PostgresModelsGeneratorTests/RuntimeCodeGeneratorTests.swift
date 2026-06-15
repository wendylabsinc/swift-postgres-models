import Testing
@testable import PostgresModelsGeneratorCore

struct RuntimeCodeGeneratorTests {
    @Test func emitsProtocolAndConformances() {
        let output = RuntimeCodeGenerator.generate()
        #expect(output.contains("protocol PostgresQueryRunner: Sendable {"))
        #expect(output.contains("func query(_ query: PostgresQuery, logger: Logger, file: String, line: Int) async throws -> PostgresRowSequence"))
        #expect(output.contains("extension PostgresConnection: PostgresQueryRunner {}"))
        #expect(output.contains("extension PostgresClient: PostgresQueryRunner {"))
    }

    @Test func doesNotEmitConvenienceOverload() {
        let output = RuntimeCodeGenerator.generate()
        // Generated query helpers call the full four-argument requirement and
        // forward file/line from their own call site, so no convenience
        // overload (which would otherwise capture the runtime file's location)
        // is emitted.
        #expect(!output.contains("func query(_ query: PostgresQuery, logger: Logger) async throws -> PostgresRowSequence"))
        #expect(!output.contains("#fileID"))
    }

    @Test func clientWrapperPromotesLoggerToOptionalToAvoidRecursion() {
        let output = RuntimeCodeGenerator.generate()
        #expect(output.contains("let optionalLogger: Logger? = logger"))
        #expect(output.contains("return try await self.query(query, logger: optionalLogger, file: file, line: line)"))
    }

    @Test func emitsRequiredImports() {
        let output = RuntimeCodeGenerator.generate()
        #expect(output.contains("import Logging"))
        #expect(output.contains("import PostgresNIO"))
    }
}
