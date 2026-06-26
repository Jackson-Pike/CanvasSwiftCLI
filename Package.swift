// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CanvasCLISwift",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "CanvasCore", targets: ["CanvasCore"]),
        .executable(name: "CanvasApp", targets: ["CanvasApp"]),
    ],
    targets: [
        .target(
            name: "CanvasCore",
            path: "Sources/CanvasCore"
        ),
        .executableTarget(
            name: "CanvasApp",
            dependencies: ["CanvasCore"],
            path: "CanvasApp",
            exclude: ["App/Info.plist"]
        ),
        .testTarget(
            name: "CanvasCoreTests",
            dependencies: ["CanvasCore"],
            path: "Tests/CanvasCoreTests"
        )
    ]
)
