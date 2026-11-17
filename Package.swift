// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "topd",
    platforms: [.macOS(.v14)],
    targets: [
        // Sampling and preference rules. No AppKit or SwiftUI, so other front ends can reuse it.
        .target(
            name: "TopdCore",
            path: "Sources/TopdCore",
            linkerSettings: [.linkedFramework("IOKit")]
        ),
        .executableTarget(
            name: "topd",
            dependencies: ["TopdCore"],
            path: "Sources/topd"
        ),
        // Behavior checks. Plain executable on purpose: this machine has Command Line Tools only,
        // which ship without XCTest and the Swift Testing macro plugins. Run with `swift run topd-checks`.
        .executableTarget(
            name: "topd-checks",
            dependencies: ["TopdCore"],
            path: "Checks"
        ),
    ]
)
