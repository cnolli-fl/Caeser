// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Caeser",
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
        )
    ]
)
