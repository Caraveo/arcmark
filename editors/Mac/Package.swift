// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ArcMarkStudio",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "ArcMarkStudio", targets: ["ArcMarkStudio"])],
    targets: [
        .executableTarget(name: "ArcMarkStudio", resources: [.process("Resources")]),
        .testTarget(name: "ArcMarkStudioTests", dependencies: ["ArcMarkStudio"])
    ]
)
