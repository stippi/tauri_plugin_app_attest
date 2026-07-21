// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "tauri-plugin-app-attest",
    // Tauri links Swift packages with a 13.0 deployment target; the
    // DCAppAttestService calls (iOS 14+) are #available-guarded.
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
    ],
    products: [
        .library(
            name: "tauri-plugin-app-attest",
            type: .static,
            targets: ["tauri-plugin-app-attest"]
        ),
    ],
    dependencies: [
        .package(name: "Tauri", path: "../.tauri/tauri-api")
    ],
    targets: [
        .target(
            name: "tauri-plugin-app-attest",
            dependencies: [.byName(name: "Tauri")],
            path: "Sources"
        ),
    ]
)
