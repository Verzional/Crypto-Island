// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CryptoIsland",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "CryptoIsland",
            targets: ["CryptoIsland"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "CryptoIsland",
            dependencies: [],
            path: "Sources",
            exclude: ["AppIcon.icns"]
        ),
        .testTarget(
            name: "CryptoIslandTests",
            dependencies: ["CryptoIsland"],
            path: "Tests"
        )
    ]
)
