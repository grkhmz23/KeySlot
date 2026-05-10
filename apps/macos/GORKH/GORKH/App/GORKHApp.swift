import SwiftUI

@main
struct GORKHApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            GORKHShellView()
                .environmentObject(appState)
                .environmentObject(appState.walletManager)
                .frame(minWidth: 1180, minHeight: 760)
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active {
                        appState.walletManager.lockForAppInactivity()
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1360, height: 860)
        .windowResizability(.contentMinSize)
    }
}
