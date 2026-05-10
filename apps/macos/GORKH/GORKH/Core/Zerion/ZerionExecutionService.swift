import Foundation

struct ZerionExecutionService {
    let runner: ZerionCLICommandRunner

    func executeTinySwap(
        proposal: ZerionTinySwapProposal,
        approval: ZerionExecutionApproval,
        context: ZerionExecutionPolicyContext
    ) -> ZerionExecutionResult {
        let decision = ZerionExecutionPolicy.validate(proposal: proposal, approval: approval, context: context)
        guard decision.canExecute else {
            return .failed(decision.blockingReasons.joined(separator: " "))
        }

        let plan: ZerionSwapCommandPlan
        do {
            plan = try ZerionSwapCommandBuilder.build(proposal: proposal, helpProbe: context.helpProbe)
        } catch {
            return .failed(error.localizedDescription)
        }

        let commandResult = runner.run(
            commandName: plan.commandName,
            arguments: plan.arguments,
            requiresAPIKey: plan.requiresAPIKey
        )
        return ZerionExecutionResultParser.parse(commandResult: commandResult, fallbackChain: proposal.chain)
    }
}
