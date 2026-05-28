import SwiftUI

struct RecoveryPhraseConfirmationView: View {
    let words: [String]
    let onConfirmed: () -> Void

    @State private var answers: [Int: String] = [:]
    @State private var attempted = false

    private var challengeIndexes: [Int] {
        [2, 6, 10].filter { $0 < words.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Confirm selected words before KeySlot stores the local signer.")
                .font(.callout)
                .foregroundStyle(GorkhColors.secondaryText)

            ForEach(challengeIndexes, id: \.self) { index in
                SecureField("Word #\(index + 1)", text: Binding(
                    get: { answers[index, default: ""] },
                    set: { answers[index] = $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }

            if attempted && !isCorrect {
                Text("Those words do not match the generated recovery phrase.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.danger)
            }

            Button {
                attempted = true
                guard isCorrect else {
                    return
                }
                onConfirmed()
            } label: {
                Label("Finalize Wallet", systemImage: "checkmark.seal")
            }
            .buttonStyle(.keyslotPrimary)
            .disabled(challengeIndexes.contains { answers[$0, default: ""].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        }
    }

    private var isCorrect: Bool {
        challengeIndexes.allSatisfy { index in
            answers[index, default: ""]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() == words[index]
        }
    }
}
