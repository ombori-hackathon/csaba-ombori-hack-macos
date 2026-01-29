// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CsabaOmboriHackClient",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "CsabaOmboriHackClient",
            path: "Sources"
        ),
    ]
)
