// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Noto",
    defaultLocalization: "zh-Hans",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "Noto", targets: ["Noto"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Noto",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
