// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Scribbles-N-Scripts",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "Scribbles-N-Scripts",
            targets: ["ScribblesNScripts"]
        )
    ],
    targets: [
        .executableTarget(
            name: "ScribblesNScripts",
            path: "Sources/Manuscript"
        ),
        .testTarget(
            name: "ScribblesNScriptsTests",
            dependencies: ["ScribblesNScripts"],
            path: "Tests/ManuscriptTests"
        )
    ]
)
