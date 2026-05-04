// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ResourcePlannerCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ResourcePlannerCore", targets: ["ResourcePlannerCore"]),
    ],
    targets: [
        .target(
            name: "ResourcePlannerCore",
            path: "ResourcePlanner/Model"
        ),
        .testTarget(
            name: "ResourcePlannerCoreTests",
            dependencies: ["ResourcePlannerCore"],
            path: "ResourcePlannerTests"
        ),
    ]
)
