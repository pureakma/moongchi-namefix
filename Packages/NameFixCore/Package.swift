// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "NameFixCore", platforms: [.macOS(.v14)], products: [.library(name: "NameFixCore", targets: ["NameFixCore"])], targets: [.target(name: "NameFixCore"), .testTarget(name: "NameFixCoreTests", dependencies: ["NameFixCore"])])
