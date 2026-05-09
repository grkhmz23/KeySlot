import SwiftUI

struct SwapTokenSelectorView: View {
    let title: String
    @Binding var selection: String
    let tokenOptions: [SwapTokenOption]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
            Picker(title, selection: $selection) {
                ForEach(tokenOptions) { option in
                    Text("\(option.symbol) \(option.uiAmountString)").tag(option.mintAddress)
                }
            }
            .frame(width: 230)

            if let selected = tokenOptions.first(where: { $0.mintAddress == selection }) {
                HStack(spacing: 6) {
                    Text(selected.isNativeSOL ? "Native SOL" : selected.mintAddress.shortAddress)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(GorkhColors.secondaryText)
                        .textSelection(.enabled)
                    if !selected.canUseAsInput {
                        GorkhStatusChip(title: "Blocked", systemImage: "lock", color: GorkhColors.warning)
                    }
                }
            }
        }
    }
}
