// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VaporNotifications",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "VaporNotifications",
            targets: ["VaporNotifications"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "3.0.3"),
        .package(url: "https://github.com/vapor/jwt.git", .upToNextMajor(from: "3.0.0")),
        .package(url: "https://github.com/apple/swift-nio-http2", .branch("master")),
        .package(url: "https://github.com/apple/swift-nio.git", from: "1.10.0"),
        .package(url: "https://github.com/MihaelIsaev/FCM.git", from: "0.6.2")


        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "VaporNotifications",
            dependencies: ["JWT", "Vapor", "NIO","NIOHTTP2", "FCM"]),
    ]
)
