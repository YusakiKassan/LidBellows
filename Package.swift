// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "LidBellows",
    platforms: [.macOS(.v14)],
    targets: [
        // Pure logic (bellows physics, key layout, chords): no AppKit, unit tested.
        .target(name: "BellowsCore"),
        .executableTarget(name: "LidBellows", dependencies: ["BellowsCore"]),
        .testTarget(name: "BellowsCoreTests", dependencies: ["BellowsCore"]),
    ],
    swiftLanguageModes: [.v5]
)
