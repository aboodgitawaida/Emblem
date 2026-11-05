// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Emblem",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Emblem", path: "Sources/Emblem"),
    ]
)
