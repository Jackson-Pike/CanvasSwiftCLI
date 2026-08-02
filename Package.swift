// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CanvasCLISwift",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CanvasCore", targets: ["CanvasCore"]),
        .library(name: "CanvasData", targets: ["CanvasData"]),
        .library(name: "CanvasUI", targets: ["CanvasUI"]),
        .executable(name: "CanvasApp", targets: ["CanvasApp"]),
    ],
    targets: [
        .target(name: "CanvasCore", path: "Sources/CanvasCore"),
        .target(name: "CanvasData", dependencies: ["CanvasCore"], path: "Sources/CanvasData"),
        .target(name: "CanvasUI", dependencies: ["CanvasCore", "CanvasData"], path: "Sources/CanvasUI"),
        .executableTarget(
            name: "CanvasApp",
            dependencies: ["CanvasCore", "CanvasData", "CanvasUI"],
            path: "CanvasApp",
            exclude: ["App/Info.plist"]
        ),
        .testTarget(name: "CanvasCoreTests", dependencies: ["CanvasCore"], path: "Tests/CanvasCoreTests"),
        .testTarget(name: "CanvasDataTests", dependencies: ["CanvasData", "CanvasCore"], path: "Tests/CanvasDataTests"),
    ]
)
