import SwiftUI

@main
struct StillApp: App {
    @State private var appState = StillApp.makeAppState()
    @Environment(\.scenePhase) private var scenePhase

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
        #if DEBUG
        if let demo = DemoLaunch.appState() {
            return demo
        }
        #endif
        return AppState(container: .live())
    }
}
