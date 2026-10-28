// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "88Editor",
    defaultLocalization: "es",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "88Editor",
            targets: ["88Editor"]
        ),
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "88Editor",
            dependencies: [],
            path: "Sources/88Editor",
            resources: [
                .process("Resources")
            ]
        ),
    ]
)
