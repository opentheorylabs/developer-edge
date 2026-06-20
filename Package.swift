// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DeveloperEdge",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/Defaults", from: "8.0.0"),
        .package(url: "https://github.com/EmergeTools/Pow", from: "1.0.0"),
        .package(url: "https://github.com/sindresorhus/LaunchAtLogin-Modern", from: "1.0.0"),
        .package(url: "https://github.com/orchetect/MenuBarExtraAccess", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "DeveloperEdge",
            dependencies: [
                .product(name: "Defaults", package: "Defaults"),
                .product(name: "Pow", package: "Pow"),
                .product(name: "LaunchAtLogin", package: "LaunchAtLogin-Modern"),
                .product(name: "MenuBarExtraAccess", package: "MenuBarExtraAccess")
            ],
            path: "Sources/DeveloperEdge"
        )
    ]
)
