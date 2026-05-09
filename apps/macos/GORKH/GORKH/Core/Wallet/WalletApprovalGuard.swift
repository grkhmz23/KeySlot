import CryptoKit
import Foundation

enum WalletSigningPreflightError: LocalizedError, Equatable {
    case walletLocked
    case missingSimulation
    case approvalRejected
    case missingPreparedMessage
    case draftMismatch
    case missingSecret
    case blockedWarnings

    var errorDescription: String? {
        switch self {
        case .walletLocked:
            return "Unlock the wallet before signing."
        case .missingSimulation:
            return "Simulate this transaction before signing."
        case .approvalRejected:
            return "Approval requirements are not complete."
        case .missingPreparedMessage:
            return "Prepared transaction message is missing. Simulate again."
        case .draftMismatch:
            return "The approved draft changed after simulation. Simulate again before signing."
        case .missingSecret:
            return "The signing seed is not available in memory."
        case .blockedWarnings:
            return "This token transfer has blocking warnings."
        }
    }
}

struct WalletSigningPreflightContext: Equatable {
    let network: WalletNetwork
    let simulation: SimulationResult?
    let mainnetConfirmation: String
    let hasCompletedDevnetSmoke: Bool
    let allowsUnavailableSimulation: Bool
    let vaultState: WalletVaultState
    let hasUnlockedSecret: Bool
    let hasPreparedMessage: Bool
    let preparedDraftFingerprint: String?
    let currentDraftFingerprint: String
    let hasBlockingWarnings: Bool
}

enum WalletApprovalGuard {
    static func validate(_ context: WalletSigningPreflightContext) throws {
        guard context.vaultState == .unlocked else {
            throw WalletSigningPreflightError.walletLocked
        }
        guard context.hasUnlockedSecret else {
            throw WalletSigningPreflightError.missingSecret
        }
        guard context.simulation != nil else {
            throw WalletSigningPreflightError.missingSimulation
        }
        guard TransactionApprovalPolicy.canApprove(
            network: context.network,
            simulation: context.simulation,
            mainnetConfirmation: context.mainnetConfirmation,
            hasCompletedDevnetSmoke: context.hasCompletedDevnetSmoke,
            allowsUnavailableSimulation: context.allowsUnavailableSimulation
        ) else {
            throw WalletSigningPreflightError.approvalRejected
        }
        guard context.hasPreparedMessage else {
            throw WalletSigningPreflightError.missingPreparedMessage
        }
        guard context.preparedDraftFingerprint == context.currentDraftFingerprint else {
            throw WalletSigningPreflightError.draftMismatch
        }
        guard !context.hasBlockingWarnings else {
            throw WalletSigningPreflightError.blockedWarnings
        }
    }

    static func fingerprint(draft: TransactionDraft) -> String {
        hash([
            "sol",
            draft.id.uuidString,
            draft.network.rawValue,
            draft.fromAddress,
            draft.toAddress,
            "\(draft.amountLamports)",
            draft.memo ?? ""
        ])
    }

    static func fingerprint(draft: TokenTransferDraft) -> String {
        hash([
            "spl",
            draft.id.uuidString,
            draft.network.rawValue,
            draft.ownerAddress,
            draft.sourceTokenAccount,
            draft.mintAddress,
            draft.tokenProgramKind.rawValue,
            draft.recipientOwnerAddress,
            draft.recipientTokenAccount ?? "",
            "\(draft.amountRaw)",
            "\(draft.decimals)",
            "\(draft.ataPlan.shouldCreateAssociatedTokenAccount)"
        ])
    }

    private static func hash(_ parts: [String]) -> String {
        let canonical = parts.joined(separator: "\u{1f}")
        let digest = SHA256.hash(data: Data(canonical.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
