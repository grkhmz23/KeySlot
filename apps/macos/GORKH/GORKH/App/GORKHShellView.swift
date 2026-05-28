import SwiftUI

struct KeySlotShellView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationSplitView {
            List(KeySlotModule.allCases, selection: $appState.selectedModule) { module in
                Label(module.title, systemImage: module.systemImage)
                    .tag(module)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
            .scrollContentBackground(.hidden)
            .background(GorkhColors.sidebar)
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Text("KeySlot")
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
                case .agent:
                    AgentView()
                case .transactionStudio:
                    TransactionStudioView()
                case .developerWorkstation:
                    DeveloperWorkstationView()
                        .environmentObject(appState)
                case .settings:
                    SettingsView()
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
