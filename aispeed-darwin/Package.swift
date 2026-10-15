// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "aispeed-darwin",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "aispeed-darwin-arm64", targets: ["aispeed"])],
    targets: [
        .executableTarget(
            name: "aispeed",
            path: "Sources/aispeed",
            linkerSettings: [.linkedFramework("Metal"), .linkedFramework("MetalPerformanceShaders")]
        )
    ]
)
