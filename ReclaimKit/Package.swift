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
        .testTarget(
            name: "ReclaimKitTests",
            // Supabase for `JSONObject`, so the wire tests use the SDK's own
            // encoder rather than a guess at it.
            dependencies: ["ReclaimKit", .product(name: "Supabase", package: "supabase-swift")]
        )
    ]
)
