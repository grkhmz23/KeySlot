import CryptoKit
import Foundation

enum OrcaHarvestConstants {
    static let whirlpoolProgramID = "whirLbMiicVdio4qvUfM5KAg6Ct8VwpYzGff3uctyCc"
    static let maxPlanAgeSeconds: TimeInterval = 120
    static let source = "official-orca-sdk-harvest-instructions"

    static let allowedProgramIDs: Set<String> = [
        whirlpoolProgramID,
        SolanaConstants.systemProgramID,
        TokenProgramKind.splToken.programID,
        TokenProgramKind.token2022.programID,
        "ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL",
        "ComputeBudget111111111111111111111111111111",
        "MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr",
        "SysvarRent111111111111111111111111111111111"
    ]
}

enum OrcaHarvestError: LocalizedError, Equatable {
    case invalidPosition(String)
    case missingPlan
    case stalePlan
    case reviewFailed(String)
    case simulationRequired
    case simulationFailed(String)
    case signingBlocked(String)

    var errorDescription: String? {
        switch self {
        case .invalidPosition(let message),
             .reviewFailed(let message),
             .simulationFailed(let message),
             .signingBlocked(let message):
            return message
        case .missingPlan:
            return "Build and review an Orca harvest plan first."
        case .stalePlan:
            return "The Orca harvest plan expired. Refresh the plan before signing."
        case .simulationRequired:
            return "Simulate the Orca harvest transaction before approval."
        }
    }
}

struct OrcaHarvestDraft: Codable, Equatable, Identifiable {
    let id: UUID
    let walletID: UUID
    let walletPublicAddress: String
    let network: WalletNetwork
    let positionMint: String
    let positionAddress: String
    let poolAddress: String
    let plan: OrcaHarvestPlan
    let createdAt: Date

    init(
        id: UUID = UUID(),
        walletID: UUID,
        walletPublicAddress: String,
        network: WalletNetwork,
        positionMint: String,
        positionAddress: String,
        poolAddress: String,
        plan: OrcaHarvestPlan,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.walletID = walletID
        self.walletPublicAddress = walletPublicAddress
        self.network = network
        self.positionMint = positionMint
        self.positionAddress = positionAddress
        self.poolAddress = poolAddress
        self.plan = plan
        self.createdAt = createdAt
    }

    func isStale(relativeTo date: Date = Date()) -> Bool {
        date.timeIntervalSince(createdAt) > OrcaHarvestConstants.maxPlanAgeSeconds || plan.isExpired(relativeTo: date)
    }
}

struct OrcaHarvestReview: Codable, Equatable {
    let baseReview: SwapTransactionReview
    let instructionCount: Int
    let writableAccountCount: Int
    let unknownProgramIDs: [String]
    let warnings: [String]
    let blockingReasons: [String]

    var canApprove: Bool {
        baseReview.canApprove && blockingReasons.isEmpty
    }

    var messageBase64: String {
        baseReview.messageBase64
    }

    var transactionFingerprint: String {
        baseReview.transactionFingerprint
    }
}

struct OrcaHarvestApprovalContext: Equatable {
    let draft: OrcaHarvestDraft
    let review: OrcaHarvestReview
    let simulation: SimulationResult?
    let network: WalletNetwork
    let walletPublicKey: String
    let mainnetConfirmation: String
    let hasCompletedDevnetSmoke: Bool
    let vaultState: WalletVaultState
    let hasUnlockedSecret: Bool
    let hasPreparedMessage: Bool
    let currentFingerprint: String
    let preparedFingerprint: String?
}

enum OrcaHarvestReviewer {
    static func review(
        draft: OrcaHarvestDraft,
        serializedTransactionBase64: String,
        expectedWallet: String
    ) throws -> OrcaHarvestReview {
        let base = try SwapTransactionReviewer.review(
            serializedTransactionBase64: serializedTransactionBase64,
            expectedWallet: expectedWallet
        )
        var warnings = base.warnings
        var blockingReasons = base.blockingReasons

        if draft.plan.source != OrcaHarvestConstants.source {
            blockingReasons.append("Orca harvest plan source is not allowlisted.")
        }
        if draft.plan.walletPublicAddress != expectedWallet {
            blockingReasons.append("Orca harvest plan wallet does not match the selected wallet.")
        }
        if draft.isStale() {
            blockingReasons.append("Orca harvest plan is stale.")
        }
        let expectedSignerSet: Set<String> = [expectedWallet]
        let signerSet = Set(base.signerAccounts)
        if signerSet != expectedSignerSet {
            blockingReasons.append("Orca harvest transaction has unexpected signer accounts.")
        }
        if !draft.plan.programIDs.contains(OrcaHarvestConstants.whirlpoolProgramID)
            && !base.programSummaries.contains(where: { $0.programID == OrcaHarvestConstants.whirlpoolProgramID }) {
            blockingReasons.append("Orca Whirlpool program is missing from the harvest transaction.")
        }
        if draft.plan.instructions.isEmpty {
            blockingReasons.append("Orca harvest plan contains no instructions.")
        }

        let programIDs = Set(base.programSummaries.map(\.programID))
        let unknown = programIDs.subtracting(OrcaHarvestConstants.allowedProgramIDs).sorted()
        if !unknown.isEmpty {
            warnings.append("Orca harvest transaction references unrecognized program IDs: \(unknown.joined(separator: ", ")).")
        }
        if draft.plan.writableAccountCount > 32 || base.writableAccounts.count > 32 {
            warnings.append("Orca harvest transaction has a high writable account count.")
        }

        return OrcaHarvestReview(
            baseReview: base,
            instructionCount: draft.plan.instructionCount,
            writableAccountCount: draft.plan.writableAccountCount,
            unknownProgramIDs: unknown,
            warnings: warnings,
            blockingReasons: blockingReasons
        )
    }
}

enum OrcaHarvestApprovalGuard {
    static func validate(_ context: OrcaHarvestApprovalContext) throws {
        guard context.vaultState == .unlocked else {
            throw OrcaHarvestError.signingBlocked("Unlock the wallet before signing this Orca harvest.")
        }
        guard context.hasUnlockedSecret else {
            throw OrcaHarvestError.signingBlocked("The signing seed is not available in memory.")
        }
        guard !context.draft.isStale() else {
            throw OrcaHarvestError.stalePlan
        }
        guard context.draft.walletPublicAddress == context.walletPublicKey,
              context.draft.plan.walletPublicAddress == context.walletPublicKey else {
            throw OrcaHarvestError.signingBlocked("Orca harvest plan does not match the selected wallet.")
        }
        guard context.review.canApprove else {
            throw OrcaHarvestError.reviewFailed(context.review.blockingReasons.joined(separator: " "))
        }
        guard let simulation = context.simulation else {
            throw OrcaHarvestError.simulationRequired
        }
        guard simulation.status == .success else {
            throw OrcaHarvestError.simulationFailed(simulation.errorMessage ?? "Orca harvest simulation failed.")
        }
        guard TransactionApprovalPolicy.canApprove(
            network: context.network,
            simulation: context.simulation,
            mainnetConfirmation: context.mainnetConfirmation,
            hasCompletedDevnetSmoke: context.hasCompletedDevnetSmoke,
            allowsUnavailableSimulation: false
        ) else {
            throw OrcaHarvestError.signingBlocked("Approval requirements are not complete.")
        }
        guard context.hasPreparedMessage else {
            throw OrcaHarvestError.signingBlocked("Prepared Orca harvest transaction is missing. Simulate again.")
        }
        guard context.preparedFingerprint == context.currentFingerprint else {
            throw OrcaHarvestError.signingBlocked("The approved Orca harvest changed after simulation. Build and simulate again.")
        }
    }

    static func fingerprint(draft: OrcaHarvestDraft) -> String {
        let canonical = [
            "orca-harvest",
            draft.id.uuidString,
            draft.network.rawValue,
            draft.walletPublicAddress,
            draft.positionMint,
            draft.positionAddress,
            draft.poolAddress,
            draft.plan.source,
            draft.plan.instructions.map { "\($0.programID):\($0.accounts.map(\.address).joined(separator: ",")):\($0.dataBase64)" }.joined(separator: "|")
        ].joined(separator: "\u{1f}")
        let digest = SHA256.hash(data: Data(canonical.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
