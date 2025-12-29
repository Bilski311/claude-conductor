// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClaudeConductor",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ClaudeConductor", targets: ["ClaudeConductor"])
    ],
    dependencies: [
        // Terminal emulation
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.2.0"),
    ],
    targets: [
        .executableTarget(
            name: "ClaudeConductor",
            dependencies: [
                "SwiftTerm",
            ],
            path: "Sources/ClaudeConductor"
        ),
        .testTarget(
            name: "ClaudeConductorTests",
            dependencies: ["ClaudeConductor"],
            path: "Tests/ClaudeConductorTests"
        )
    ]
)
