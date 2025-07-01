// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WolfWhisper",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "WolfWhisper",
            targets: ["WolfWhisper"]
        ),
    ],
    dependencies: [
        // No external dependencies - using native macOS APIs
    ],
    targets: [
        .executableTarget(
            name: "WolfWhisper",
            dependencies: [
                // No external dependencies
            ],
            path: "WolfWhisper",
            exclude: ["Info.plist"],
            resources: [
                .process("Assets.xcassets")
            ]
        ),
    ]
) 