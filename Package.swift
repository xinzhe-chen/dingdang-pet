// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DingdangPet",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "DingdangPetCore", targets: ["DingdangPetCore"]),
        .executable(name: "DingdangPet", targets: ["DingdangPetApp"]),
        .executable(name: "dingdang-pet-tool", targets: ["DingdangPetTool"])
    ],
    targets: [
        .target(
            name: "DingdangPetCore",
            path: "Sources/DingdangPetCore"
        ),
        .executableTarget(
            name: "DingdangPetApp",
            dependencies: ["DingdangPetCore"],
            path: "Sources/DingdangPetApp",
            exclude: ["Resources"]
        ),
        .executableTarget(
            name: "DingdangPetTool",
            dependencies: ["DingdangPetCore"],
            path: "Sources/DingdangPetTool"
        ),
        .testTarget(
            name: "DingdangPetCoreTests",
            dependencies: ["DingdangPetCore"],
            path: "Tests/DingdangPetCoreTests"
        )
    ],
    swiftLanguageVersions: [.v5]
)
