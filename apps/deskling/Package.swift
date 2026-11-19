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
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.4"),
    ],
    targets: [
        // Foundation only, so the hook starts fast and stays small.
        .target(name: "DesklingEvents"),
        .executableTarget(name: "DesklingHook", dependencies: ["DesklingEvents"]),
        .target(name: "DesklingKit", dependencies: [
            "DesklingEvents", .product(name: "Lottie", package: "lottie-ios"), .product(name: "Sparkle", package: "Sparkle"),
        ]),
        // Sparkle.framework is bundled in Contents/Frameworks (scripts/assemble.sh).
        .executableTarget(
            name: "Deskling", dependencies: ["DesklingKit"],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]),
        .executableTarget(name: "IconTool", dependencies: ["DesklingKit"]),
        .testTarget(name: "DesklingKitTests", dependencies: ["DesklingKit", "DesklingEvents"]),
    ]
)
