// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StatefulReadModelDemo",
    platforms: [
        .macOS(.v15),
    ],
    dependencies: [
        .package(path: "../../"),
    ],
    targets: [
        .executableTarget(
            name: "StatefulReadModelDemo",
            dependencies: [
                .product(name: "DDDKit", package: "swift-ddd-kit"),
                .product(name: "ReadModelPersistence", package: "swift-ddd-kit"),
            ],
            path: "Sources"
        ),
    ]
)
