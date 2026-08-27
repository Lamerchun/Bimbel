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
        .package(url: "https://github.com/ekazaev/ChatLayout.git", from: "2.4.0"),
        .package(url: "https://github.com/nathantannar4/InputBarAccessoryView.git", from: "7.0.0")
    ],
    targets: [
        .target(
            name: "Bimbel",
            dependencies: [
                .product(name: "ChatLayout", package: "ChatLayout"),
                .product(name: "InputBarAccessoryView", package: "InputBarAccessoryView")
            ],
            path: "Sources/Bimbel",
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        ),
        .testTarget(
            name: "BimbelTests",
            dependencies: ["Bimbel"],
            path: "Tests/BimbelTests"
        )
    ]
)
