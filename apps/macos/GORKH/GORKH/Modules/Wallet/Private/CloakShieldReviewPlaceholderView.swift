import SwiftUI

struct CloakShieldReviewPlaceholderView: View {
    private let steps = [
        "Deposit draft",
        "Fee and minimum check",
        "SDK and environment valid",
        "Signer preflight",
        "Shield review",
        "Explicit approval",
        "Local signing",
        "Cloak SDK execution",
        "Activity log"
    ]

    var body: some View {
        GorkhPanel("Shield Review") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Cloak shield and full-withdraw actions use the same safety posture as SOL and SPL sends, plus scoped signer bridge review.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)

                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(spacing: 8) {
                        Text("\(index + 1)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(GorkhColors.panelElevated)
                            .clipShape(Circle())
                        Text(step)
                            .font(.caption)
                            .foregroundStyle(index < 4 ? GorkhColors.primaryText : GorkhColors.secondaryText)
                        if step == "Cloak SDK execution" {
                            GorkhStatusChip(title: "approved only", systemImage: "signature", color: GorkhColors.warning)
                        }
                    }
                }
            }
        }
    }
}
