// swift-tools-version: 5.9
// Copyright 2026 Seth Dillingham
// SPDX-License-Identifier: Apache-2.0

import PackageDescription

let package = Package(
    name: "rewrap-markdown",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "rewrap-markdown", targets: ["rewrap-markdown"]),
        .library(name: "RewrapMarkdownCore", targets: ["RewrapMarkdownCore"]),
    ],
    targets: [
        .target(name: "RewrapMarkdownCore"),
        .executableTarget(
            name: "rewrap-markdown",
            dependencies: ["RewrapMarkdownCore"]
        ),
        .testTarget(
            name: "RewrapMarkdownCoreTests",
            dependencies: ["RewrapMarkdownCore"]
        ),
    ]
)
