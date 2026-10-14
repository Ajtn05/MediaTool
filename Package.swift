// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MediaTool",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MediaTool", targets: ["MediaTool"])
    ],
    targets: [
        .executableTarget(
            name: "MediaTool"
        )
    ]
)
