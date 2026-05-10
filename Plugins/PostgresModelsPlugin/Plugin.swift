import Foundation
import PackagePlugin

@main
struct PostgresModelsPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        guard let target = target as? SourceModuleTarget else { return [] }
        let generator = try context.tool(named: "PostgresModelsGenerator")

        let inputFiles = target.sourceFiles.filter { file in
            let name = file.url.lastPathComponent
            return name.hasSuffix(".query.sql") || name.hasSuffix(".migration.sql")
        }

        guard !inputFiles.isEmpty else { return [] }

        let outputDir = context.pluginWorkDirectoryURL

        var outputFiles: [URL] = []
        var hasMigrations = false
        for file in inputFiles {
            let name = file.url.lastPathComponent
            if name.hasSuffix(".query.sql") {
                let stem = String(name.dropLast(".query.sql".count))
                outputFiles.append(outputDir.appending(component: "\(stem).swift"))
            } else if name.hasSuffix(".migration.sql") {
                hasMigrations = true
            }
        }
        if hasMigrations {
            outputFiles.append(outputDir.appending(component: "Migrations.swift"))
        }

        return [
            .buildCommand(
                displayName: "Generating SQL helpers",
                executable: generator.url,
                arguments: [outputDir.path(percentEncoded: false)]
                    + inputFiles.map { $0.url.path(percentEncoded: false) },
                inputFiles: inputFiles.map { $0.url },
                outputFiles: outputFiles
            ),
        ]
    }
}
