// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Manuscript",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "Manuscript",
            targets: ["Manuscript"]
        )
    ],
    targets: [
        .executableTarget(
            name: "Manuscript",
            path: "Sources/Manuscript"
        ),
        .testTarget(
            name: "ManuscriptTests",
            dependencies: ["Manuscript"],
            path: "Tests/ManuscriptTests"
        )
    ]
)
