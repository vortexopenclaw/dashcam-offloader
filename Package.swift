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
    targets: [
        .executableTarget(
            name: "DashcamOffloaderApp",
            path: "Sources/DashcamOffloaderApp"
        )
    ]
)
