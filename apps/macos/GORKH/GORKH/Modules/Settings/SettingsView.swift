import SwiftUI

struct SettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Settings")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                    .foregroundStyle(GorkhColors.primaryText)

                SecuritySettingsView()

                GorkhPanel("Wallet Safety") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Phase 1 keeps signer access local to this Mac.")
                            .foregroundStyle(GorkhColors.primaryText)
                        Text("Agent execution, staking execution, lending execution, bridging, and autonomous sends are intentionally not implemented. Swaps require native review, simulation, approval, and local signing.")
                            .foregroundStyle(GorkhColors.secondaryText)
                    }
                }

                Spacer()
            }
            .padding(28)
            .frame(maxWidth: 860, alignment: .topLeading)
        }
    }
}
