// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Awareness",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "Awareness",
            path: "Sources/Awareness",
            resources: [
                .copy("Resources")
            ]
        )
    ]
)
