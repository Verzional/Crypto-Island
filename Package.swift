// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CryptoNotch",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "CryptoNotch",
            targets: ["CryptoNotch"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "CryptoNotch",
            dependencies: [],
            path: "Sources",
            exclude: ["AppIcon.icns"]
        ),
        .testTarget(
            name: "CryptoNotchTests",
            dependencies: ["CryptoNotch"],
            path: "Tests"
        )
    ]
)
