// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TodoApp",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../.."),
        .package(url: "https://github.com/vapor/postgres-nio.git", from: "1.21.0"),
    ],
    targets: [
        .executableTarget(
            name: "TodoApp",
            dependencies: [
                .product(name: "PostgresNIO", package: "postgres-nio"),
            ],
            plugins: [
                .plugin(name: "PostgresModelsPlugin", package: "swift-postgres-models"),
            ]
        ),
    ]
)
