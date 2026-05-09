import SwiftUI

struct PortfolioDeFiPlaceholderView: View {
    private let items = [
        ("DeFi positions", "coming later"),
        ("LP positions", "coming later"),
        ("Lending positions", "coming later"),
        ("Stake accounts", "coming later"),
        ("PnL", "coming later")
    ]

    var body: some View {
        GorkhPanel("DeFi-Ready Summary") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Portfolio Core stores read-only balance and price summaries for future DeFi adapters. No DeFi execution exists in this phase.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(items, id: \.0) { item in
                        HStack {
                            Text(item.0)
                                .font(.caption)
                                .foregroundStyle(GorkhColors.primaryText)
                            Spacer()
                            GorkhStatusChip(title: item.1, systemImage: "clock", color: GorkhColors.warning)
                        }
                        .padding(8)
                        .background(GorkhColors.panelElevated.opacity(0.45))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }
}
