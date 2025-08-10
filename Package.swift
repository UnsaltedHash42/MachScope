// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MachScope",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "machscope", targets: ["MachScopeCLI"]),
        .library(name: "MachScopeCore", targets: ["MachScopeCore"])
    ],
    targets: [
        .target(
            name: "SecurityBridge",
            path: "Sources/SecurityBridge",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedFramework("Security")
            ]
        ),
        .target(
            name: "MachScopeCore",
            dependencies: ["SecurityBridge"],
            path: "Sources/MachScopeCore",
            resources: [
                .process("Rules/DefaultRules.yml")
            ],
            linkerSettings: [
                .linkedFramework("Security")
            ]
        ),
        .executableTarget(
            name: "MachScopeCLI",
            dependencies: ["MachScopeCore"],
            path: "Sources/MachScopeCLI"
        ),
        .testTarget(
            name: "MachScopeCoreTests",
            dependencies: ["MachScopeCore"],
            path: "Tests/MachScopeCoreTests",
            resources: [
                .process("Golden"),
                .process("Fixtures")
            ]
        )
    ]
)


