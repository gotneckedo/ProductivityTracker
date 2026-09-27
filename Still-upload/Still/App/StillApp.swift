import SwiftUI

@main
struct StillApp: App {
    @State private var appState = StillApp.makeAppState()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        StillFontRegistration.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .onAppear { appState.bootstrap() }
                .onOpenURL { url in appState.handle(url: url) }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        appState.handleBecameActive()
                    }
                }
        }
    }

    private static func makeAppState() -> AppState {
        // `STILL_PROOF` is supplied only to the CI Release configuration. It
        // preserves the real release feature flags while allowing deterministic
        // simulator navigation for truth-pass screenshots. App Store builds do
        // not carry this condition or these launch arguments.
        #if DEBUG || STILL_PROOF
        if let demo = DemoLaunch.appState() {
            return demo
        }
        #endif
        return AppState(container: .live())
    }
}
