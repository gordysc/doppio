// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Doppio",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "DoppioCore"),
        .executableTarget(name: "Doppio", dependencies: ["DoppioCore"]),
        .testTarget(name: "DoppioCoreTests", dependencies: ["DoppioCore"]),
    ]
)
