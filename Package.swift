// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AirPodsAdaptive",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "AirPodsAdaptive", targets: ["AirPodsMenu"]),
        .executable(name: "airpods-probe", targets: ["AirPodsProbe"])
    ],
    targets: [
        .target(name: "AirPodsCore", linkerSettings: [.linkedFramework("IOBluetooth"), .linkedFramework("CoreAudio")]),
        .executableTarget(name: "AirPodsMenu", dependencies: ["AirPodsCore"]),
        .executableTarget(name: "AirPodsProbe", dependencies: ["AirPodsCore"]),
        .executableTarget(name: "PacketChecks", dependencies: ["AirPodsCore"], path: "Tests/PacketChecks")
    ]
)
