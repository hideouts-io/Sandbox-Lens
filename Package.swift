// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SandboxLens",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "SandboxLens", targets: ["SandboxLens"])
    ],
    targets: [
        .executableTarget(
            name: "SandboxLens",
            path: "Sources/SandboxLens",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "SandboxLensTests",
            dependencies: ["SandboxLens"],
            path: "Tests/SandboxLensTests"
        )
    ]
)
