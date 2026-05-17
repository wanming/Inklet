// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Fluenta",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "WritingPopoverCore", targets: ["WritingPopoverCore"]),
        .executable(name: "WritingPopoverApp", targets: ["WritingPopoverApp"])
    ],
    targets: [
        .target(name: "WritingPopoverCore"),
        .executableTarget(
            name: "WritingPopoverApp",
            dependencies: ["WritingPopoverCore"]
        ),
        .testTarget(
            name: "WritingPopoverCoreTests",
            dependencies: ["WritingPopoverCore"]
        )
    ]
)
