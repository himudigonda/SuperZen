// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "SuperZenCore",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "SuperZenCore", targets: ["SuperZenCore"])
  ],
  targets: [
    .target(name: "SuperZenCore"),
    .testTarget(name: "SuperZenCoreTests", dependencies: ["SuperZenCore"]),
  ]
)
