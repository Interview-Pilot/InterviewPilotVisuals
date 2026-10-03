// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "InterviewPilotVisuals",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "InterviewPilotVisuals", targets: ["InterviewPilotVisuals"]),
    ],
    targets: [
        .target(name: "InterviewPilotVisuals"),
        .testTarget(
            name: "InterviewPilotVisualsTests",
            dependencies: ["InterviewPilotVisuals"]
        ),
    ]
)
