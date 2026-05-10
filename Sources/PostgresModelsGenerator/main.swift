import Foundation
import PostgresModelsGeneratorCore

guard CommandLine.arguments.count >= 2 else {
    fputs("Usage: PostgresModelsGenerator <output-dir> [files...]\n", stderr)
    exit(1)
}

let outputDir = CommandLine.arguments[1]
let outputURL = URL(fileURLWithPath: outputDir)
let inputPaths = Array(CommandLine.arguments.dropFirst(2))
var currentPath = ""

do {
    var migrationInputs: [(name: String, contents: String)] = []

    for path in inputPaths {
        currentPath = path
        let url = URL(fileURLWithPath: path)
        let filename = url.lastPathComponent
        let contents = try String(contentsOf: url, encoding: .utf8)

        if filename.hasSuffix(".query.sql") {
            let stem = String(filename.dropLast(".query.sql".count))
            let structName = IdentifierSanitizer.structName(from: stem)
            let parsed = try SQLParser.parseQueryFile(contents)
            if parsed.queries.isEmpty {
                fputs("warning: \(filename) has no @query blocks\n", stderr)
            }
            let output = QueryCodeGenerator.generate(from: parsed, structName: structName)
            try output.write(to: outputURL.appendingPathComponent("\(stem).swift"), atomically: true, encoding: .utf8)
        } else if filename.hasSuffix(".migration.sql") {
            migrationInputs.append((name: filename, contents: contents))
        }
    }

    if !migrationInputs.isEmpty {
        let sorted = migrationInputs.sorted { $0.name < $1.name }
        let migrations = sorted.map { SQLParser.parseMigrationFile(name: $0.name, contents: $0.contents) }
        let output = MigrationCodeGenerator.generate(from: migrations)
        try output.write(to: outputURL.appendingPathComponent("Migrations.swift"), atomically: true, encoding: .utf8)
    }
} catch let error as SQLParserError {
    switch error {
    case .missingQueryKind(let line):
        fputs("error: \(currentPath): missing query kind (:one, :many, :exec) — \(line)\n", stderr)
    case .unknownQueryKind(let kind):
        fputs("error: \(currentPath): unknown query kind '\(kind)' — expected :one, :many, or :exec\n", stderr)
    case .paramCountMismatch(let name, let declared, let placeholders):
        fputs("error: \(currentPath): param count mismatch in query '\(name)': \(declared) params declared, \(placeholders) placeholders found\n", stderr)
    case .unsupportedType(let type, let queryName):
        fputs("error: \(currentPath): unsupported type '\(type)' in query '\(queryName)' — supported: UUID, String, Int, Double, Bool, Date (and optionals)\n", stderr)
    case .missingReturns(let name):
        fputs("error: \(currentPath): query '\(name)' is :one/:many but has no @returns\n", stderr)
    case .multipleReturnsLines(let name):
        fputs("error: \(currentPath): query '\(name)' has multiple @returns lines\n", stderr)
    case .emptySQLBody(let name):
        fputs("error: \(currentPath): query '\(name)' has annotations but no SQL body\n", stderr)
    case .malformedAnnotation(let s):
        fputs("error: \(currentPath): malformed annotation '\(s)'\n", stderr)
    }
    exit(1)
} catch {
    fputs("error: \(currentPath.isEmpty ? "" : "\(currentPath): ")\(error)\n", stderr)
    exit(1)
}
