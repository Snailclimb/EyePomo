// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "EyePomoCore",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "EyePomoCore", targets: ["EyePomoCore"]),
        .executable(name: "EyePomoCoreValidation", targets: ["EyePomoCoreValidation"])
    ],
    targets: [
        .target(name: "EyePomoCore"),
        .executableTarget(
            name: "EyePomoCoreValidation",
            dependencies: ["EyePomoCore"]
        )
    ]
)
