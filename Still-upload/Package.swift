// swift-tools-version:5.9
//
// StillCore: the platform-neutral half of the app (domain, data, services,
// controllers, and the observable app state and router), compiled as a package
// so its unit tests run with `swift test` on macOS or Linux, no simulator needed.
//
// The iOS app itself is built from Still.xcodeproj, which compiles these same
// files together with the SwiftUI layer.
import PackageDescription

let package = Package(
    name: "StillCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "StillCore", targets: ["StillCore"])
    ],
    targets: [
        .target(
            name: "StillCore",
            path: "Still",
            exclude: [
                // The SwiftUI layer and app resources build only in Still.xcodeproj.
                "App/StillApp.swift",
                "App/RootView.swift",
                "App/DependencyContainer+Live.swift",
                "App/DemoLaunch.swift",
                "DesignSystem",
                "Features",
                "Resources",
                "Assets.xcassets",
                "Info.plist",
                "Still.entitlements"
            ],
            sources: [
                "Domain",
                "Data",
                "Services",
                "Shared",
                "App/DependencyContainer.swift",
                "App/AppState.swift",
                "App/AppState+Features.swift",
                "App/AppRouter.swift",
                "App/PreviewSupport.swift"
            ]
        ),
        .testTarget(
            name: "StillCoreTests",
            dependencies: ["StillCore"],
            path: "StillTests"
        )
    ]
)
