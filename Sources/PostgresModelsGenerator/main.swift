#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import PostgresModelsGeneratorCore

#if canImport(FoundationEssentials)
func writeStandardError(_ message: String) {
    if let data = message.data(using: .utf8) {
        FileHandle.standardError.write(data)
    }
}
#else
func writeStandardError(_ message: String) {
    fputs(message, stderr)
}
#endif

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

guard CommandLine.arguments.count >= 2 else {
    writeStandardError("Usage: PostgresModelsGenerator <output-dir> [files...]\n")
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
                writeStandardError("warning: \(filename) has no @query blocks\n")
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
        writeStandardError("error: \(currentPath): missing query kind (:one, :many, :exec) — \(line)\n")
    case .unknownQueryKind(let kind):
        writeStandardError("error: \(currentPath): unknown query kind '\(kind)' — expected :one, :many, or :exec\n")
    case .paramCountMismatch(let name, let declared, let placeholders):
        writeStandardError("error: \(currentPath): param count mismatch in query '\(name)': \(declared) params declared, \(placeholders) placeholders found\n")
    case .unsupportedType(let type, let queryName):
        writeStandardError("error: \(currentPath): unsupported type '\(type)' in query '\(queryName)' — supported: UUID, String, Int, Double, Bool, Date (and optionals)\n")
    case .missingReturns(let name):
        writeStandardError("error: \(currentPath): query '\(name)' is :one/:many but has no @returns\n")
    case .multipleReturnsLines(let name):
        writeStandardError("error: \(currentPath): query '\(name)' has multiple @returns lines\n")
    case .emptySQLBody(let name):
        writeStandardError("error: \(currentPath): query '\(name)' has annotations but no SQL body\n")
    case .malformedAnnotation(let s):
        writeStandardError("error: \(currentPath): malformed annotation '\(s)'\n")
    }
    exit(1)
} catch {
    writeStandardError("error: \(currentPath.isEmpty ? "" : "\(currentPath): ")\(error)\n")
    exit(1)
}
