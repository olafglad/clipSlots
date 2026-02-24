// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "clipslots",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", "1.2.0"..<"1.4.0"),
        .package(url: "https://github.com/dduan/TOMLDecoder.git", "0.2.2"..<"0.3.0"),
        .package(url: "https://github.com/soffes/HotKey.git", from: "0.2.0")
    ],
    targets: [
        .executableTarget(
            name: "clipslots",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "TOMLDecoder", package: "TOMLDecoder"),
                .product(name: "HotKey", package: "HotKey")
            ]
        )
    ]
)