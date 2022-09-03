// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "OdinKit",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "OdinKit",
            type: .dynamic,
            targets: ["OdinKit"])
    ],
    targets: [
        .target(
            name: "OdinKit",
            dependencies: ["Odin"],
            path: "Sources"),
        .testTarget(
            name: "OdinKitTests",
            dependencies: ["OdinKit"],
            path: "Tests"),
        .binaryTarget(
            name: "Odin",
            path: "Frameworks/Odin.xcframework")
    ]
)
