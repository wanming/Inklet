// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Fluenta",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "WritingPopoverCore", targets: ["WritingPopoverCore"]),
        .executable(name: "Fluenta", targets: ["Fluenta"])
    ],
    targets: [
        .target(name: "WritingPopoverCore"),
        .executableTarget(
            name: "Fluenta",
            dependencies: ["WritingPopoverCore"],
            path: "Sources/WritingPopoverApp"
        ),
        .testTarget(
            name: "WritingPopoverCoreTests",
            dependencies: ["WritingPopoverCore"]
        )
    ]
)
