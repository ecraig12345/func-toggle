// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "FuncToggle",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "FuncToggle", targets: ["FuncToggle"])],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", exact: "1.14.0")
    ],
    targets: [
        .target(name: "FunctionKeys"),
        .executableTarget(
            name: "FuncToggle",
            dependencies: [
                "FunctionKeys",
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")
            ]
        ),
        .testTarget(name: "FunctionKeysTests", dependencies: ["FunctionKeys"])
    ],
    swiftLanguageModes: [.v6]
)
