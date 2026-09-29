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
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.4")
    ],
    targets: [
        .executableTarget(
            name: "CryptoNotch",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
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
