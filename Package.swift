// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Dictee",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Dictee", path: "Sources/Dictee")
    ]
)
