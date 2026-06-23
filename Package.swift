// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "EyePomo",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "EyePomo", targets: ["EyePomo"])
    ],
    dependencies: [
        .package(path: "Packages/EyePomoCore")
    ],
    targets: [
        .executableTarget(
            name: "EyePomo",
            dependencies: ["EyePomoCore"],
            path: "EyePomoApp",
            exclude: [
                "EyePomo.entitlements",
                "Resources/Info.plist"
            ],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
