// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DashcamOffloader",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "DashcamOffloader", targets: ["DashcamOffloaderApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/getsentry/sentry-cocoa", exact: "9.35.0")
    ],
    targets: [
        .executableTarget(
            name: "DashcamOffloaderApp",
            dependencies: [
                .product(name: "Sentry", package: "sentry-cocoa")
            ],
            path: "Sources/DashcamOffloaderApp"
        )
    ]
)
