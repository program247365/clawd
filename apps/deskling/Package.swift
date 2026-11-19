// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Deskling",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Deskling", targets: ["Deskling"]),
        .executable(name: "deskling-hook", targets: ["DesklingHook"]),
    ],
    dependencies: [
        .package(url: "https://github.com/airbnb/lottie-ios", from: "4.5.0"),
    ],
    targets: [
        // Foundation only, so the hook starts fast and stays small.
        .target(name: "DesklingEvents"),
        .executableTarget(name: "DesklingHook", dependencies: ["DesklingEvents"]),
        .target(name: "DesklingKit", dependencies: ["DesklingEvents", .product(name: "Lottie", package: "lottie-ios")]),
        .executableTarget(name: "Deskling", dependencies: ["DesklingKit"]),
        .executableTarget(name: "IconTool", dependencies: ["DesklingKit"]),
        .testTarget(name: "DesklingKitTests", dependencies: ["DesklingKit", "DesklingEvents"]),
    ]
)
