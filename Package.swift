// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotchEye",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "NotchEye",
            path: "NotchEye",
            swiftSettings: [
                .unsafeFlags(["-swift-version", "5"]),
            ],
            linkerSettings: [
                .linkedFramework("CoreMediaIO"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("AppKit"),
                .linkedFramework("UserNotifications"),
            ]
        ),
    ]
)
