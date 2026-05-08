import SwiftUI

struct SettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Settings")
                .font(.largeTitle)
                .fontWeight(.semibold)
                .foregroundStyle(GorkhColors.primaryText)

            GorkhPanel("Wallet Safety") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Phase 1 keeps signer access local to this Mac.")
                        .foregroundStyle(GorkhColors.primaryText)
                    Text("Agent execution, swaps, staking, lending, bridging, and autonomous sends are intentionally not implemented.")
                        .foregroundStyle(GorkhColors.secondaryText)
                }
            }

            Spacer()
        }
        .padding(28)
    }
}
