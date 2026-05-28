import SwiftUI

struct DeveloperWorkstationLocalnetView: View {
    let selectedCluster: WorkstationCluster
    let developerWallet: DeveloperWalletMetadata
    let localValidatorStatus: WorkstationLocalValidatorStatus
    @Binding var localValidatorResetPhrase: String
    @Binding var faucetAddress: String
    @Binding var faucetAmount: String
    let faucetStatus: String
    let onGenerateDeveloperWallet: () -> Void
    let onDeleteDeveloperWallet: () -> Void
    let onRequestDevnetAirdrop: (String, String, WorkstationRPCPermission) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            developerWalletPanel
            localValidatorPanel
            faucetPanel
        }
    }

    private var developerWalletPanel: some View {
        GorkhPanel("Developer Wallet") {
            DeveloperWorkstationKeyValueRow(key: "Status", value: developerWallet.status.title)
            DeveloperWorkstationKeyValueRow(key: "Public address", value: developerWallet.publicAddress.isEmpty ? "Not generated" : developerWallet.publicAddress)
            HStack {
                Button("Generate Developer Wallet", action: onGenerateDeveloperWallet)
                    .buttonStyle(.borderedProminent)
                Button("Delete Developer Wallet", action: onDeleteDeveloperWallet)
                    .disabled(developerWallet.status != .ready)
            }
            Text("This wallet is separate from the main KeySlot wallet and is for localnet/devnet payer/deployer use only.")
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
        }
    }

    private var localValidatorPanel: some View {
        GorkhPanel("Local Validator") {
            Text("Status detection uses localnet RPC health. Start uses solana-test-validator with fixed args and an Application Support ledger path.")
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
            WorkstationStatusChip(
                title: localValidatorStatus.state.title,
                systemImage: localValidatorStatus.state == .running ? "checkmark.circle" : "server.rack",
                color: localValidatorStatus.state == .running ? GorkhColors.success : GorkhColors.warning
            )
            Text(localValidatorStatus.message)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
            if let validatorPath = WorkstationToolchainResolver().companionExecutablePath(named: "solana-test-validator", nextTo: .solana) {
                let ledger = WorkstationLocalValidatorLifecycle.ledgerPath()
                let plan = WorkstationLocalValidatorCommandBuilder.start(
                    validatorPath: validatorPath,
                    ledgerPath: ledger,
                    reset: false
                )
                DeveloperWorkstationKeyValueRow(key: "Start preview", value: plan.redactedPreview)
                DeveloperWorkstationLabeledTextField(
                    label: "Reset phrase",
                    text: $localValidatorResetPhrase,
                    prompt: WorkstationLocalValidatorResetPolicy.requiredPhrase
                )
                DeveloperWorkstationKeyValueRow(
                    key: "Reset allowed",
                    value: WorkstationLocalValidatorResetPolicy.canReset(phrase: localValidatorResetPhrase) ? "Yes" : "No"
                )
                DeveloperWorkstationKeyValueRow(
                    key: "Stop policy",
                    value: WorkstationLocalValidatorLifecycle.stopMessage(status: localValidatorStatus)
                )
            } else {
                Text("solana-test-validator was not found next to a validated Solana CLI executable.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.warning)
            }
        }
    }

    private var faucetPanel: some View {
        GorkhPanel("Devnet / Localnet Faucet") {
            DeveloperWorkstationLabeledTextField(
                label: "Recipient",
                text: $faucetAddress,
                prompt: developerWallet.publicAddress.isEmpty ? "Public key" : developerWallet.publicAddress
            )
            DeveloperWorkstationLabeledTextField(label: "SOL amount", text: $faucetAmount, prompt: "0.5")
            let amount = Double(faucetAmount) ?? 0
            let recipient = faucetAddress.isEmpty ? developerWallet.publicAddress : faucetAddress
            let permission = WorkstationFaucetPolicy.validate(
                WorkstationFaucetRequest(cluster: selectedCluster, publicAddress: recipient, amountSOL: amount)
            )
            WorkstationStatusChip(
                title: permission.isAllowed ? "Faucet request allowed" : "Faucet blocked",
                systemImage: permission.isAllowed ? "drop" : "lock",
                color: permission.isAllowed ? GorkhColors.success : GorkhColors.warning
            )
            Text(permission.message)
                .font(.caption)
                .foregroundStyle(permission.isAllowed ? GorkhColors.success : GorkhColors.warning)
            Button("Request Devnet Airdrop") {
                onRequestDevnetAirdrop(recipient, faucetAmount, permission)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!permission.isAllowed || selectedCluster != .devnet)
            Text(faucetStatus)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
        }
    }
}
