// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Caeser",
    defaultLocalization: "pt-BR",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(
            name: "Caeser",
            targets: ["Caeser"]
        )
    ],
    targets: [
        .executableTarget(
            name: "Caeser",
            path: "Sources/VideoDownloader",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "CaeserTests",
            dependencies: ["Caeser"],
            path: "Tests"
        )
    ]
)
