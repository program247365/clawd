// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Clawd",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/airbnb/lottie-ios", from: "4.5.0"),
    ],
    targets: [
        .target(name: "ClawdKit", dependencies: [.product(name: "Lottie", package: "lottie-ios")]),
        .executableTarget(name: "Clawd", dependencies: ["ClawdKit"]),
        .testTarget(name: "ClawdKitTests", dependencies: ["ClawdKit"]),
    ]
)
