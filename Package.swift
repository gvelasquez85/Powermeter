// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "Powermeter", platforms: [.macOS(.v13)], products: [.executable(name: "Powermeter", targets: ["Powermeter"])], targets: [.target(name: "PowerCore"), .executableTarget(name: "Powermeter", dependencies: ["PowerCore"]), .testTarget(name: "PowerCoreTests", dependencies: ["PowerCore"])], swiftLanguageModes: [.v5])
