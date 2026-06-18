// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Mousy",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Mousy",
            path: "Sources/Mousy"
        )
    ]
)
