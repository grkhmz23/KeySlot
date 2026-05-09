import SwiftUI

struct CloakApprovalRequirementsView: View {
    @EnvironmentObject private var walletManager: WalletManager

    var body: some View {
        GorkhPanel("Approval Requirements") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Cloak signing requires every native wallet gate before any local signature can be produced.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(requirements) { requirement in
                        HStack(spacing: 8) {
                            Image(systemName: icon(for: requirement))
                                .foregroundStyle(requirement == .executionLocked ? GorkhColors.warning : GorkhColors.accent)
                            Text(requirement.title)
                                .font(.caption)
                                .foregroundStyle(GorkhColors.primaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Text("Phase 2.5 enables scoped Cloak deposit/full-withdraw signing only after review, mainnet phrase, LocalAuthentication, and audit. Other private actions remain locked.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.warning)
            }
        }
    }

    private var requirements: [CloakSignerApprovalRequirement] {
        walletManager.cloakSignerPreflightResult?.requirements ?? CloakSignerBridgePolicy.locked.approvalRequirements
    }

    private func icon(for requirement: CloakSignerApprovalRequirement) -> String {
        switch requirement {
        case .walletUnlocked, .localAuthentication:
            return "lock.open"
        case .explicitUserApproval, .mainnetConfirmationPhrase:
            return "checkmark.seal"
        case .auditBeforeSigning, .auditAfterSigning:
            return "list.bullet.clipboard"
        case .executionLocked:
            return "lock.fill"
        default:
            return "checkmark.shield"
        }
    }
}
