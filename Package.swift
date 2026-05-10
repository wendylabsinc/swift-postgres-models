// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "swift-postgres-models",
    platforms: [.macOS(.v14)],
    products: [
        .plugin(name: "PostgresModelsPlugin", targets: ["PostgresModelsPlugin"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/postgres-nio.git", from: "1.21.0"),
    ],
    targets: [
        .plugin(
            name: "PostgresModelsPlugin",
            capability: .buildTool(),
            dependencies: ["PostgresModelsGenerator"]
        ),
        .target(name: "PostgresModelsGeneratorCore"),
        .executableTarget(
            name: "PostgresModelsGenerator",
            dependencies: ["PostgresModelsGeneratorCore"]
        ),
        .testTarget(
            name: "PostgresModelsGeneratorTests",
            dependencies: ["PostgresModelsGeneratorCore"]
        ),
        .testTarget(
            name: "PostgresModelsIntegrationTests",
            dependencies: [
                .product(name: "PostgresNIO", package: "postgres-nio"),
            ]
        ),
    ]
)
