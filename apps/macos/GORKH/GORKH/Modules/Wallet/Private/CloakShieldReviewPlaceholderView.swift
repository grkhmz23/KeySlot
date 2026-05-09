import SwiftUI

struct CloakShieldReviewPlaceholderView: View {
    private let steps = [
        "Deposit draft",
        "Fee and minimum check",
        "Cloak bridge availability",
        "Signer preflight",
        "Shield review",
        "Explicit approval",
        "Execute",
        "Audit"
    ]

    var body: some View {
        GorkhPanel("Shield Review") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Future Cloak actions will use the same safety posture as SOL and SPL sends.")
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
                            .foregroundStyle(index < 3 ? GorkhColors.primaryText : GorkhColors.secondaryText)
                        if index >= 5 {
                            GorkhStatusChip(title: "locked", systemImage: "lock", color: GorkhColors.warning)
                        }
                    }
                }
            }
        }
    }
}
