import SwiftUI

struct CloakSafetyPanelView: View {
    private let items = [
        "Cloak deposit/full-withdraw can execute only after explicit mainnet approval.",
        "No wallet signing seed or private key is passed to a Node or TypeScript helper.",
        "TypeScript cannot sign. Native Swift signer remains the only signing authority.",
        "No Cloak notes, UTXOs, viewing keys, nullifiers, proof inputs, or raw scan cache are stored in plain app settings.",
        "Mainnet deposits require unlock, LocalAuthentication, signer preflight, Shield review, explicit approval, and Activity logging.",
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
