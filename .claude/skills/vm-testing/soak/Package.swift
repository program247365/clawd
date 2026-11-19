// swift-tools-version:5.10
import PackageDescription
let package = Package(
    name: "soak", platforms: [.macOS(.v14)],
    dependencies: [.package(url: "https://github.com/airbnb/lottie-ios", exact: "4.6.1")],
    targets: [.executableTarget(name: "soak", dependencies: [.product(name: "Lottie", package: "lottie-ios")])])
