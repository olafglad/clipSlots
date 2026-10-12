// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "clipslots",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "clipslots", targets: ["clipslots"]),
        .executable(name: "ClipSlotsApp", targets: ["ClipSlotsApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", "1.2.0"..<"1.4.0"),
        .package(url: "https://github.com/dduan/TOMLDecoder.git", "0.2.2"..<"0.3.0"),
        .package(url: "https://github.com/soffes/HotKey.git", from: "0.2.0")
    ],
    targets: [
        // Shared engine: storage, config, clipboard, hotkeys. Used by both
        // the CLI and the menubar app so they read and write the same slots.
        .target(
            name: "ClipSlotsCore",
            dependencies: [
                .product(name: "TOMLDecoder", package: "TOMLDecoder"),
                .product(name: "HotKey", package: "HotKey")
            ]
        ),
        .executableTarget(
            name: "clipslots",
            dependencies: [
                "ClipSlotsCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        // Menubar app. `make app` wraps this binary into ClipSlots.app
        // (see scripts/build-app.sh); it is not meant to be run bare.
        .executableTarget(
            name: "ClipSlotsApp",
            dependencies: [
                "ClipSlotsCore",
                .product(name: "HotKey", package: "HotKey")
            ]
        )
    ]
)
