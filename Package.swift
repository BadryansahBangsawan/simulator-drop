// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SimulatorDrop",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "SimulatorDrop", targets: ["SimulatorDrop"])
    ],
    targets: [
        .executableTarget(name: "SimulatorDrop", path: "Sources")
    ]
)
