// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "InstalogCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "InstalogCore", targets: ["InstalogCore"])
    ],
    targets: [
        .target(
            name: "InstalogCore",
            resources: [.copy("Resources/catalog.sqlite")],
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .testTarget(
            name: "InstalogCoreTests",
            dependencies: ["InstalogCore"]
        ),
    ]
)
