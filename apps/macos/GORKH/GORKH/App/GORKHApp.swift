import SwiftUI

@main
struct GORKHApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            GORKHShellView()
                .environmentObject(appState)
                .environmentObject(appState.walletManager)
                .frame(minWidth: 1180, minHeight: 760)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
