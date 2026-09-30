// swift-tools-version: 6.2
import PackageDescription

let runtimeDependencies: [Target.Dependency] = [
    "OrchardDomain",
    .product(name: "ContainerAPIClient", package: "container"),
    .product(name: "MachineAPIClient", package: "container"),
    .product(name: "ContainerResource", package: "container"),
    .product(name: "ContainerPersistence", package: "container"),
    .product(name: "TerminalProgress", package: "container"),
    .product(name: "ContainerizationOCI", package: "containerization"),
    .product(name: "ContainerizationExtras", package: "containerization"),
    .product(name: "ArgumentParser", package: "swift-argument-parser"),
]

let package = Package(
    name: "OrchardCore",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "OrchardDomain", targets: ["OrchardDomain"]),
        .library(name: "OrchardRuntime", targets: ["OrchardRuntime"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/container.git", exact: "1.4.1"),
        .package(url: "https://github.com/apple/containerization.git", exact: "0.45.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.7.0"),
    ],
    targets: [
        .target(name: "OrchardDomain"),
        .target(name: "OrchardRuntime", dependencies: runtimeDependencies),
        .testTarget(name: "OrchardDomainTests", dependencies: ["OrchardDomain"]),
        .testTarget(name: "OrchardRuntimeTests", dependencies: runtimeDependencies + ["OrchardRuntime"]),
    ]
)
