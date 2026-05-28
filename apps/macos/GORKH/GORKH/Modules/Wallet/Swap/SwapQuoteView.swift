import SwiftUI

struct SwapQuoteView: View {
    let quote: JupiterQuoteSummary?
    let inputDecimals: UInt8?
    let outputDecimals: UInt8?

    var body: some View {
        GorkhPanel("Quote") {
            if let quote {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        GorkhStatusChip(
                            title: quote.isStale() ? "Stale" : "Fresh",
                            systemImage: quote.isStale() ? "clock.badge.exclamationmark" : "checkmark.seal",
                            color: quote.isStale() ? GorkhColors.warning : GorkhColors.success
                        )
                        GorkhStatusChip(title: quoteAgeText(quote), systemImage: "clock", color: quote.isStale() ? GorkhColors.warning : GorkhColors.accent)
                        GorkhStatusChip(title: String(format: "%.2f%% slippage", Double(quote.slippageBps) / 100.0), systemImage: "slider.horizontal.3", color: GorkhColors.accent)
                    }

                    HStack(spacing: 12) {
                        metric("Input", value: formatted(raw: quote.inAmount, decimals: inputDecimals), monospaced: true)
                        metric("Expected output", value: formatted(raw: quote.outAmount, decimals: outputDecimals), monospaced: true)
                        metric("Minimum received", value: formatted(raw: quote.otherAmountThreshold, decimals: outputDecimals), monospaced: true)
                        metric("Price impact", value: quote.priceImpactPct.map { "\($0)%" } ?? "Unavailable")
                    }

                    Text("Route: \(quote.routeLabel)")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                        .lineLimit(2)

                    Text("Quoted \(quote.quotedAt.formatted(date: .omitted, time: .standard))")
                        .font(.caption2)
                        .foregroundStyle(GorkhColors.secondaryText)
                }
            } else {
                Text("Request a quote to see route, output estimate, slippage, and minimum received.")
                    .foregroundStyle(GorkhColors.secondaryText)
            }
        }
    }

    private func metric(_ title: String, value: String, monospaced: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
            Text(value)
                .font(monospaced ? .system(.callout, design: .monospaced) : .callout)
                .fontWeight(.medium)
                .foregroundStyle(GorkhColors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatted(raw: UInt64, decimals: UInt8?) -> String {
        guard let decimals else {
            return "\(raw) raw"
        }
        return TokenAmountFormatter.format(rawAmount: raw, decimals: decimals)
    }

    private func quoteAgeText(_ quote: JupiterQuoteSummary) -> String {
        let age = max(0, Int(Date().timeIntervalSince(quote.quotedAt)))
        return "\(age)s old"
    }
}
