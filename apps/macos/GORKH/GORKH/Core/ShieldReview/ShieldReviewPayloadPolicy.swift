import Foundation

enum ShieldReviewPayloadPolicy {
    static let defaultExpirySeconds: TimeInterval = 10 * 60
    static let maxTransactionBytes = 256_000

    private static let forbiddenNeedles = [
        "mnemonic",
        "seed phrase",
        "privatekey",
        "secretkey",
        "wallet json",
        "signingseed",
        "utxo",
        "viewingkey",
        "nullifier",
        "deepseek_api_key"
    ]

    static func makeHandoff(
        sourceFlow: ShieldReviewSourceFlow,
        safeSummary: String,
        transactionBase64: String?,
        now: Date = Date()
    ) -> ShieldReviewStudioHandoff {
        let sanitizedSummary = AgentSafetyRedactor.redact(safeSummary)
        guard let transactionBase64, transactionBase64.isEmpty == false else {
            return summaryOnly(sourceFlow: sourceFlow, safeSummary: sanitizedSummary, now: now)
        }
        guard isSafeTransientTransactionBase64(transactionBase64) else {
            return ShieldReviewStudioHandoff(
                sourceFlow: sourceFlow,
                safeSummary: sanitizedSummary,
                transientTransactionBase64: nil,
                createdAt: now,
                expiresAt: now.addingTimeInterval(defaultExpirySeconds),
                redactionStatus: "transient_payload_rejected",
                payloadAvailability: .unavailable,
                unavailableReason: "Transient transaction payload failed local safety validation."
            )
        }
        return ShieldReviewStudioHandoff(
            sourceFlow: sourceFlow,
            safeSummary: sanitizedSummary,
            transientTransactionBase64: transactionBase64,
            createdAt: now,
            expiresAt: now.addingTimeInterval(defaultExpirySeconds),
            redactionStatus: "redacted_safe",
            payloadAvailability: .transientPayload,
            unavailableReason: nil
        )
    }

    static func summaryOnly(
        sourceFlow: ShieldReviewSourceFlow,
        safeSummary: String,
        now: Date = Date()
    ) -> ShieldReviewStudioHandoff {
        ShieldReviewStudioHandoff(
            sourceFlow: sourceFlow,
            safeSummary: AgentSafetyRedactor.redact(safeSummary),
            transientTransactionBase64: nil,
            createdAt: now,
            expiresAt: now.addingTimeInterval(defaultExpirySeconds),
            redactionStatus: "redacted_safe",
            payloadAvailability: .summaryOnly,
            unavailableReason: nil
        )
    }

    static func isSafeTransientTransactionBase64(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = Data(base64Encoded: trimmed), data.isEmpty == false, data.count <= maxTransactionBytes else {
            return false
        }
        let lower = trimmed.lowercased()
        return forbiddenNeedles.allSatisfy { lower.contains($0) == false }
    }
}
