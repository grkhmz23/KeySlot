import SwiftUI

struct AuditLogView: View {
    @EnvironmentObject private var walletManager: WalletManager

    var body: some View {
        GorkhPanel("Audit Log") {
            if walletManager.auditEvents.isEmpty {
                Text("No sensitive wallet actions have been recorded yet.")
                    .foregroundStyle(GorkhColors.secondaryText)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(walletManager.auditEvents.prefix(10)) { event in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(event.kind.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(.callout)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(GorkhColors.primaryText)
                                Spacer()
                                Text(event.createdAt.formatted(date: .abbreviated, time: .standard))
                                    .font(.caption)
                                    .foregroundStyle(GorkhColors.secondaryText)
                            }
                            Text(event.message)
                                .font(.caption)
                                .foregroundStyle(GorkhColors.secondaryText)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }
}
