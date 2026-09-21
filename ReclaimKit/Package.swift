// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ReclaimKit",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "ReclaimKit", targets: ["ReclaimKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "ReclaimKit",
            dependencies: [.product(name: "Supabase", package: "supabase-swift")],
            resources: [.process("Resources")]
        ),
        .testTarget(name: "ReclaimKitTests", dependencies: ["ReclaimKit"])
    ]
)
