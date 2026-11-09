// swift-tools-version: 6.2
// Created: 2026-11-08 21:10 -06:00 · Edited: 2026-11-08 21:10 -06:00
// CountdownCore (`C1`, `C2`): the countdown math, with no UI. Apple frameworks only (`D14`).
import PackageDescription

let package = Package(
    name: "CountdownCore",
    platforms: [.iOS(.v26), .macOS(.v26), .watchOS(.v26)],
    products: [.library(name: "CountdownCore", targets: ["CountdownCore"])],
    targets: [
        .target(name: "CountdownCore"),
        .testTarget(name: "CountdownCoreTests", dependencies: ["CountdownCore"]),
    ]
)
