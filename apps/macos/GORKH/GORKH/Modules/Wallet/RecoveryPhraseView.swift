import SwiftUI

struct RecoveryPhraseView: View {
    let words: [String]

    private let columns = [
        GridItem(.adaptive(minimum: 136), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Write this recovery phrase down. KeySlot cannot recover it for you.")
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(GorkhColors.warning)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(Array(words.enumerated()), id: \.offset) { item in
                    HStack(spacing: 8) {
                        Text("\(item.offset + 1)")
                            .font(.caption)
                            .foregroundStyle(GorkhColors.secondaryText)
                            .frame(width: 22, alignment: .trailing)

                        Text(item.element)
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(GorkhColors.primaryText)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(GorkhColors.background)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }

            Text("Avoid screenshots. Store this offline. Never share it with KeySlot support, an assistant, an agent, or any website.")
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
        }
    }
}
