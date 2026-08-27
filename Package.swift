// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "Bimbel",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "Bimbel", targets: ["Bimbel"])
    ],
    dependencies: [
        .package(url: "https://github.com/ekazaev/ChatLayout.git", from: "2.4.0")
    ],
    targets: [
        .target(
            name: "Bimbel",
            dependencies: [
                .product(name: "ChatLayout", package: "ChatLayout")
            ],
            path: "Sources/Bimbel",
            resources: [
                .process("PrivacyInfo.xcprivacy"),
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "BimbelTests",
            dependencies: ["Bimbel"],
            path: "Tests/BimbelTests"
        )
    ]
)
