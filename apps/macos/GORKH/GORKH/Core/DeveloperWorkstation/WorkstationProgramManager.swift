import Foundation

struct WorkstationProgramOperationRequest: Codable, Equatable {
    let operation: WorkstationProgramOperation
    let cluster: WorkstationCluster
    let project: WorkstationProject?
    let toolchain: WorkstationToolchainSnapshot
    let developerWallet: DeveloperWalletMetadata?
    let artifactPath: String?
    let programID: String?
    let exactPhrase: String?
}

enum WorkstationProgramOperationDecision: Codable, Equatable {
    case allowed(String)
    case blocked([String])

    var isAllowed: Bool {
        if case .allowed = self {
            return true
        }
        return false
    }

    var reasons: [String] {
        switch self {
        case .allowed(let reason):
            return [reason]
        case .blocked(let reasons):
            return reasons
        }
    }
}

enum WorkstationProgramManager {
    static let destructivePhrase = "I understand this local/devnet program operation can change or close a program."

    static func evaluate(_ request: WorkstationProgramOperationRequest) -> WorkstationProgramOperationDecision {
        var reasons: [String] = []

        if request.cluster == .mainnetBeta {
            reasons.append("Locked pending reviewed mainnet program-ops phase.")
        } else if request.cluster == .testnet {
            reasons.append("Testnet program operations are read-only in this phase.")
        }

        if request.operation != .solanaProgramShow {
            if let block = WorkstationTrustPolicy.blocksExecution(project: request.project) {
                reasons.append(block)
            }
            if request.developerWallet?.status != .ready {
                reasons.append("Developer Workstation wallet is required for localnet/devnet program operations.")
            }
        }

        switch request.operation {
        case .anchorBuild:
            if request.toolchain.isAvailable(.anchor) == false {
                reasons.append("Anchor CLI is required for Anchor build.")
            }
        case .anchorDeploy:
            if request.toolchain.isAvailable(.anchor) == false {
                reasons.append("Anchor CLI is required for Anchor deploy.")
            }
        case .solanaProgramDeploy, .solanaProgramShow, .solanaProgramClose, .solanaSetUpgradeAuthority:
            if request.toolchain.isAvailable(.solana) == false {
                reasons.append("Solana CLI is required for this program operation.")
            }
        }

        if request.operation == .solanaProgramDeploy && (request.artifactPath?.isEmpty ?? true) {
            reasons.append("A build artifact path is required.")
        }
        if [.solanaProgramShow, .solanaProgramClose, .solanaSetUpgradeAuthority].contains(request.operation),
           (request.programID?.isEmpty ?? true) {
            reasons.append("A program id is required.")
        }
        if [.solanaProgramClose, .solanaSetUpgradeAuthority].contains(request.operation),
           request.exactPhrase != destructivePhrase {
            reasons.append("Exact destructive-operation phrase is required.")
        }

        if reasons.isEmpty {
            return .allowed("Operation is allowed for localnet/devnet only after explicit approval.")
        }
        return .blocked(reasons)
    }
}
