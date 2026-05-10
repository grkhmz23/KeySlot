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
        let node = ZerionNodeVersionProbe(environment: environment).probe()
        return ZerionStatusSnapshot(
            cliStatus: resolution.status,
            executablePath: resolution.executablePath,
            nodeStatus: node.status,
            nodeVersion: node.version,
            apiKeyStatus: ZerionRedaction.apiKeyStatus(from: environment),
            agentTokenStatus: .unknown,
            policyStatus: .unchecked,
            swapHelpStatus: nil,
            swapCommandShape: .unchecked,
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
        let swapHelp = runner.run(.swapHelp)
        let agentHelp = runner.run(.agentHelp)
        _ = runner.run(.configList)

        let commandResults = [help, chains, wallets, policies, tokens, swapHelp, agentHelp]
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
        let node = ZerionNodeVersionProbe(environment: environment).probe()
        let helpProbe = ZerionCLIHelpParser.parse(
            topHelp: help.stdoutSummary,
            swapHelp: swapHelp.stdoutSummary,
            agentHelp: agentHelp.stdoutSummary,
            checkedAt: Date()
        )

        return ZerionStatusSnapshot(
            cliStatus: cliStatus,
            executablePath: executablePath,
            nodeStatus: node.status,
            nodeVersion: node.version,
            apiKeyStatus: ZerionRedaction.apiKeyStatus(from: environment),
            agentTokenStatus: ZerionRedaction.agentTokenStatus(from: tokens.stdoutSummary),
            policyStatus: policyStatus,
            swapHelpStatus: swapHelp.status,
            swapCommandShape: helpProbe.swapCommandShape,
            walletCount: ZerionJSONSummary.itemCount(from: wallets.stdoutSummary),
            policyCount: ZerionJSONSummary.itemCount(from: policies.stdoutSummary),
            tokenCount: ZerionJSONSummary.itemCount(from: tokens.stdoutSummary),
            supportedChains: supportedChains(from: chains.stdoutSummary),
            errors: errors,
            checkedAt: Date()
        )
    }

    func loadPolicyCenter() -> ZerionPolicyCenterSnapshot {
        let resolution = pathResolver.resolve()
        guard resolution.status == .installed, let executablePath = resolution.executablePath else {
            return ZerionPolicyCenterSnapshot(
                policies: [],
                tokens: [],
                status: .unavailable,
                unavailableReason: resolution.reason,
                updatedAt: Date()
            )
        }

        let runner = ZerionCLICommandRunner(executablePath: executablePath, environment: environment)
        let policies = runner.run(.agentListPolicies)
        let tokens = runner.run(.agentListTokens)

        guard policies.status == .succeeded || tokens.status == .succeeded else {
            return ZerionPolicyCenterSnapshot(
                policies: [],
                tokens: [],
                status: .error,
                unavailableReason: [policies.stderrSummary, tokens.stderrSummary]
                    .filter { $0.isEmpty == false }
                    .joined(separator: " "),
                updatedAt: Date()
            )
        }

        return ZerionPolicyParser.parsePolicyCenter(
            policiesText: policies.stdoutSummary,
            tokensText: tokens.stdoutSummary,
            updatedAt: Date()
        )
    }

    func loadHelpProbe() -> ZerionCLIHelpProbe {
        let resolution = pathResolver.resolve()
        guard resolution.status == .installed, let executablePath = resolution.executablePath else {
            return .unchecked
        }
        let runner = ZerionCLICommandRunner(executablePath: executablePath, environment: environment)
        let top = runner.run(.help)
        let swap = runner.run(.swapHelp)
        let agent = runner.run(.agentHelp)
        return ZerionCLIHelpParser.parse(
            topHelp: top.stdoutSummary,
            swapHelp: swap.stdoutSummary,
            agentHelp: agent.stdoutSummary,
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
