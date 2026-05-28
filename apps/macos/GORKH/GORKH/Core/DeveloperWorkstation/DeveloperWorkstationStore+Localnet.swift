import Foundation

extension DeveloperWorkstationStore {
    func generateDeveloperWallet() {
        do {
            localnetState.developerWallet = try dependencies.keyVault.generateDeveloperWallet(now: Date())
            appendActivity(.devWalletGenerated, "Developer Workstation wallet generated.")
        } catch {
            appendActivity(.commandBlocked, "Developer wallet generation failed.")
        }
    }

    func deleteDeveloperWallet() {
        let id = localnetState.developerWallet.id
        do {
            try dependencies.keyVault.deleteDeveloperWallet(id: id)
            localnetState.developerWallet = .missing
            appendActivity(.devWalletDeleted, "Developer Workstation wallet deleted.")
        } catch {
            appendActivity(.commandBlocked, "Developer wallet deletion failed.")
        }
    }

    func requestDevnetAirdrop(recipient: String, amountText: String, permission: WorkstationRPCPermission) {
        guard permission.isAllowed, selectionState.selectedCluster == .devnet else {
            localnetState.faucetStatus = "Airdrop blocked by Workstation faucet policy."
            appendActivity(.devWalletAirdropFailed, "Devnet airdrop blocked by policy.")
            return
        }

        appendActivity(.devWalletAirdropRequested, "Devnet airdrop requested.", details: ["cluster": selectionState.selectedCluster.rawValue])
        localnetState.faucetStatus = "Requesting capped devnet airdrop..."
        Task {
            do {
                let signature = try await dependencies.faucetService
                    .requestCappedDevnetFunds(address: recipient, amountText: amountText)
                await MainActor.run {
                    localnetState.faucetStatus = "Devnet airdrop requested. Signature: \(signature)"
                    appendActivity(.devWalletAirdropSucceeded, "Devnet airdrop succeeded.", details: ["signature": signature])
                }
            } catch {
                await MainActor.run {
                    localnetState.faucetStatus = "Devnet airdrop failed or rate limited."
                    appendActivity(.devWalletAirdropFailed, "Devnet airdrop failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func toggleLogs() {
        if localnetState.logState.isStreaming {
            localnetState.logState = localnetState.logState.stopped()
            appendActivity(.logsStopped, "Log stream stopped.")
            return
        }
        let permission = WorkstationLogStreamPolicy.canStream(programID: rpcState.programID)
        guard permission.isAllowed else {
            appendActivity(.commandBlocked, permission.message)
            return
        }
        localnetState.logState = localnetState.logState.started(programID: rpcState.programID)
        appendActivity(.logsStarted, "Log stream started.", details: ["cluster": selectionState.selectedCluster.rawValue])
    }
}
