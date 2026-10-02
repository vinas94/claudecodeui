// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "cloudcli-launcher",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "cloudcli-launcher", path: "Sources/cloudcli-launcher")
    ]
)
