import SwiftUI

struct CloakFeeModelView: View {
    var body: some View {
        GorkhPanel("Cloak Fee Model") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    feeRow("Minimum deposit", lamports: CloakConstants.minimumDepositLamports)
                    feeRow("Fixed fee", lamports: CloakConstants.fixedFeeLamports)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Variable fee")
                            .font(.caption)
                            .foregroundStyle(GorkhColors.secondaryText)
                        Text("amount * 3 / 1000")
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(GorkhColors.primaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text("All fee math is lamport integer math. No floating point conversion is used for protocol amounts.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            }
        }
    }

    private func feeRow(_ title: String, lamports: UInt64) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
            Text("\(lamports) lamports")
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(GorkhColors.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
