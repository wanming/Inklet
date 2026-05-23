// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Inklet",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "InkletCore", targets: ["InkletCore"]),
        .executable(name: "Inklet", targets: ["Inklet"])
    ],
    targets: [
        .target(
            name: "InkletCore",
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "Inklet",
            dependencies: ["InkletCore"],
            path: "Sources/InkletApp"
        ),
        .testTarget(
            name: "InkletCoreTests",
            dependencies: ["InkletCore"]
        )
    ]
)
