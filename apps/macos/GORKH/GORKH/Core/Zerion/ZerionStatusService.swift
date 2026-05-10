import Foundation

struct ZerionStatusService {
    private let pathResolver: ZerionCLIPathResolver
    private let environment: [String: String]

    init(
        pathResolver: ZerionCLIPathResolver = ZerionCLIPathResolver(),
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.pathResolver = pathResolver
        self.environment = environment
    }

    func localSnapshot() -> ZerionStatusSnapshot {
        let resolution = pathResolver.resolve()
        return ZerionStatusSnapshot(
            cliStatus: resolution.status,
            executablePath: resolution.executablePath,
            nodeStatus: .unchecked,
            apiKeyStatus: ZerionRedaction.apiKeyStatus(from: environment),
            agentTokenStatus: .unknown,
            policyStatus: .unchecked,
            walletCount: nil,
            policyCount: nil,
            tokenCount: nil,
            supportedChains: [],
            errors: resolution.reason.map { [ZerionRedaction.redact($0)] } ?? [],
            checkedAt: Date()
        )
    }

    func refreshReadOnlyStatus() -> ZerionStatusSnapshot {
        let resolution = pathResolver.resolve()
        guard resolution.status == .installed, let executablePath = resolution.executablePath else {
            return localSnapshot()
        }

        let runner = ZerionCLICommandRunner(executablePath: executablePath, environment: environment)
        let help = runner.run(.help)
        let chains = runner.run(.chains)
        let wallets = runner.run(.walletList)
        let policies = runner.run(.agentListPolicies)
        let tokens = runner.run(.agentListTokens)
        _ = runner.run(.configList)

        let commandResults = [help, chains, wallets, policies, tokens]
        let errors = commandResults
            .filter { $0.status != .succeeded }
            .map { "\($0.command): \($0.stderrSummary)" }
            .map(ZerionRedaction.redact)

        let cliStatus: ZerionCLIInstallStatus = help.status == .succeeded ? .installed : .error
        let policyStatus: ZerionPolicyReadStatus = {
            if policies.status == .succeeded || tokens.status == .succeeded {
                return .loaded
            }
            if policies.status == .blocked || tokens.status == .blocked {
                return .unavailable
            }
            return errors.isEmpty ? .unchecked : .error
        }()

        return ZerionStatusSnapshot(
            cliStatus: cliStatus,
            executablePath: executablePath,
            nodeStatus: .unchecked,
            apiKeyStatus: ZerionRedaction.apiKeyStatus(from: environment),
            agentTokenStatus: ZerionRedaction.agentTokenStatus(from: tokens.stdoutSummary),
            policyStatus: policyStatus,
            walletCount: ZerionJSONSummary.itemCount(from: wallets.stdoutSummary),
            policyCount: ZerionJSONSummary.itemCount(from: policies.stdoutSummary),
            tokenCount: ZerionJSONSummary.itemCount(from: tokens.stdoutSummary),
            supportedChains: supportedChains(from: chains.stdoutSummary),
            errors: errors,
            checkedAt: Date()
        )
    }

    private func supportedChains(from summary: String) -> [String] {
        guard let data = summary.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) else {
            return []
        }
        if let array = object as? [[String: Any]] {
            let names = array.compactMap { ($0["id"] ?? $0["name"] ?? $0["chain"]) as? String }
            return Array(names.prefix(8))
        }
        if let dictionary = object as? [String: Any],
           let data = dictionary["data"] as? [[String: Any]] {
            let names = data.compactMap { ($0["id"] ?? $0["name"] ?? $0["chain"]) as? String }
            return Array(names.prefix(8))
        }
        return []
    }
}
