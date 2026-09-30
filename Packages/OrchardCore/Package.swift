// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "OrchardCore",
    platforms: [.macOS(.v26)],
    products: [.library(name: "OrchardDomain", targets: ["OrchardDomain"])],
    targets: [
        .target(name: "OrchardDomain"),
        .testTarget(name: "OrchardDomainTests", dependencies: ["OrchardDomain"]),
    ]
)
