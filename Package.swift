// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "OVOBar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "OVOBar", path: "Sources/OVOBar"),
    ]
)
