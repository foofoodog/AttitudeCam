// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AttitudeCam",
    platforms: [
        .iOS(.v15),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "AttitudeCam",
            targets: ["AttitudeCam"]
        ),
    ],
    targets: [
        .target(
            name: "AttitudeCam"
        ),
    ]
)
