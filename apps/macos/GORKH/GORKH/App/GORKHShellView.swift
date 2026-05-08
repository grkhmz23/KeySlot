import SwiftUI

struct GORKHShellView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationSplitView {
            List(GORKHModule.allCases, selection: $appState.selectedModule) { module in
                Label(module.title, systemImage: module.systemImage)
                    .tag(module)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
            .scrollContentBackground(.hidden)
            .background(GorkhColors.sidebar)
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Text("GORKH")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
            }
        } detail: {
            ZStack {
                GorkhColors.background.ignoresSafeArea()

                switch appState.selectedModule {
                case .wallet:
                    WalletView()
                case .settings:
                    SettingsView()
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
