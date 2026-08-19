// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SeekES",
    defaultLocalization: "zh-Hans",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SeekES", targets: ["SeekES"])
    ],
    targets: [
        .executableTarget(
            name: "SeekES",
            path: "ElasticClient",
            resources: [
                .process("Assets.xcassets"),
                .process("en.lproj"),
                .process("zh-Hans.lproj"),
                .process("ja.lproj"),
                .process("ko.lproj"),
                .process("ru.lproj")
            ]
        )
    ]
)
