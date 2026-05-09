import SwiftUI

struct CloakPrivateHistoryPlaceholderView: View {
    var body: some View {
        GorkhPanel("Private History") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    GorkhStatusChip(title: "Scanning locked", systemImage: "lock", color: GorkhColors.warning)
                    GorkhStatusChip(title: "No private cache", systemImage: "tray", color: GorkhColors.accent)
                }

                Text("Future scanning will use Cloak viewing-key based history and compliance reports. Phase 2.0 stores no scan cache or private note material.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            }
        }
    }
}
