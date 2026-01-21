// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PassportReader",
    platforms: [.iOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/AndyQ/NFCPassportReader", from: "2.3.0"),
        // Add other SPM packages here
    ],
    targets: []
)
