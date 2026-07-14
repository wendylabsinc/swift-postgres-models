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
        .target(
            name: "CPgQuery",
            path: "Sources/CPgQuery",
            exclude: [
                "upstream/src/pg_query_outfuncs_protobuf_cpp.cc",
                "upstream/src/include",
                "upstream/src/postgres/include",
            ],
            sources: [
                "upstream/src",
                "upstream/vendor",
                "upstream/protobuf/pg_query.pb-c.c",
            ],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
                .headerSearchPath("upstream"),
                .headerSearchPath("upstream/src"),
                .headerSearchPath("upstream/src/include"),
                .headerSearchPath("upstream/src/postgres/include"),
                .headerSearchPath("upstream/vendor"),
                .headerSearchPath("upstream/vendor/protobuf-c"),
                .headerSearchPath("upstream/protobuf"),
                .unsafeFlags(["-w"]),
            ]
        ),
        .target(name: "PostgresModelsGeneratorCore"),
        .target(
            name: "PostgresModelsSchema",
            dependencies: ["CPgQuery"]
        ),
        .testTarget(
            name: "PostgresModelsSchemaTests",
            dependencies: ["PostgresModelsSchema"]
        ),
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
        .testTarget(
            name: "CPgQuerySmokeTests",
            dependencies: ["CPgQuery"]
        ),
    ]
)
