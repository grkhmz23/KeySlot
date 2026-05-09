import SwiftUI

struct CloakSafetyPanelView: View {
    private let items = [
        "No Cloak SDK transaction is executed in Phase 2.0.",
        "No wallet signing seed is passed to a Node or TypeScript helper.",
        "No Cloak notes, UTXOs, viewing keys, nullifiers, proof inputs, or raw scan cache are stored in UserDefaults.",
        "Future mainnet deposits require unlock, LocalAuthentication, Shield review, explicit approval, and audit.",
        "Agent-controlled private wallet execution is not implemented."
    ]

    var body: some View {
        GorkhPanel("Private Safety") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.shield")
                            .foregroundStyle(GorkhColors.success)
                        Text(item)
                            .font(.caption)
                            .foregroundStyle(GorkhColors.secondaryText)
                    }
                }
            }
        }
    }
}
