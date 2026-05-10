import Foundation

struct WorkstationRPCPlaygroundService {
    static func permission(for method: WorkstationRPCMethod, cluster: WorkstationCluster) -> WorkstationRPCPermission {
        switch method {
        case .sendTransaction:
            return .blocked("sendTransaction is blocked in Developer Workstation v0.1.")
        case .custom:
            return .blocked("Custom RPC method text is blocked in Developer Workstation v0.1.")
        case .getProgramAccounts:
            return .blocked("Broad getProgramAccounts scans are blocked pending a bounded reviewed flow.")
        case .requestAirdrop:
            guard cluster.allowsAirdrop else {
                return .blocked("requestAirdrop is blocked on \(cluster.title).")
            }
            return .allowedThroughFaucetOnly
        default:
            return .allowed
        }
    }

    static func validate(_ request: WorkstationRPCPlaygroundRequest) -> WorkstationRPCPermission {
        let methodPermission = permission(for: request.method, cluster: request.cluster)
        guard methodPermission.isAllowed else {
            return methodPermission
        }

        if request.method.requiresAddress {
            guard let address = request.address, SolanaAddressValidator.isValidAddress(address) else {
                return .blocked("This RPC method requires a valid public address.")
            }
        }

        if request.method.requiresSignature {
            guard let signature = request.signature,
                  let bytes = Base58.decode(signature),
                  bytes.count == 64 else {
                return .blocked("This RPC method requires a valid Solana signature.")
            }
        }

        if request.method.requiresEncodedTransaction {
            guard let encodedTransaction = request.encodedTransaction?.trimmingCharacters(in: .whitespacesAndNewlines),
                  encodedTransaction.count >= 40 else {
                return .blocked("This RPC method requires an encoded transaction or message fixture.")
            }
        }

        return methodPermission
    }

    static func makeSafeResult(
        request: WorkstationRPCPlaygroundRequest,
        rawJSON: String?,
        now: Date = Date()
    ) -> WorkstationRPCPlaygroundResult {
        let redacted = rawJSON.map { AgentSafetyRedactor.redact($0) }
        let preview = redacted.map { String($0.prefix(4_000)) }
        return WorkstationRPCPlaygroundResult(
            method: request.method,
            cluster: request.cluster,
            status: .ready,
            safeSummary: "\(request.method.title) prepared for \(request.cluster.title). Mutating methods remain blocked.",
            rawJSONPreview: preview,
            createdAt: now
        )
    }
}
