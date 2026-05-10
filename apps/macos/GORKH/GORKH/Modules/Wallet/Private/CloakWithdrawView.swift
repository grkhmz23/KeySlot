import SwiftUI

struct CloakWithdrawView: View {
    @EnvironmentObject private var walletManager: WalletManager
    @State private var selectedRecordID = ""
    @State private var recipientAddress = ""
    @State private var mainnetConfirmation = ""
    @State private var feeAcknowledged = false
    @State private var shieldReviewCompleted = false
    @State private var explicitApproval = false

    var body: some View {
        GorkhPanel("Pay Privately / Full Withdraw") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    GorkhStatusChip(title: "\(availableRecords.count) available", systemImage: "tray.full", color: availableRecords.isEmpty ? GorkhColors.warning : GorkhColors.success)
                    GorkhStatusChip(title: "Full withdraw", systemImage: "arrow.up.right.circle", color: GorkhColors.accent)
                    GorkhStatusChip(title: "Partial withdraw locked", systemImage: "lock", color: GorkhColors.warning)
                }

                if availableRecords.isEmpty {
                    Text("Shield SOL first to create a local Cloak UTXO reference. No private pay or withdraw action is available without local vault state.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                } else {
                    Picker("Shielded record", selection: $selectedRecordID) {
                        ForEach(availableRecords) { record in
                            Text("\(record.amountSOLText) / \(record.shortCommitment)")
                                .tag(record.id.uuidString)
                        }
                    }
                    .pickerStyle(.menu)

                    if let record = selectedRecord {
                        recordSummary(record)
                        let shieldReview = ShieldReviewService.reviewCloakFullWithdraw(
                            record: record,
                            recipientAddress: recipientAddress
                        )
                        ShieldReviewCard(summary: shieldReview)
                    }

                    TextField("Recipient public address", text: $recipientAddress)
                        .textFieldStyle(.roundedBorder)

                    approvalControls

                    Button {
                        guard let recordID = UUID(uuidString: selectedRecordID) else {
                            return
                        }
                        Task {
                            await walletManager.executeCloakFullWithdraw(
                                recordID: recordID,
                                recipientAddress: recipientAddress,
                                mainnetConfirmation: mainnetConfirmation,
                                feeAcknowledged: feeAcknowledged,
                                shieldReviewCompleted: shieldReviewCompleted,
                                explicitApproval: explicitApproval
                            )
                        }
                    } label: {
                        Label("Approve, Authenticate, Sign, and Withdraw", systemImage: "signature")
                    }
                    .buttonStyle(.gorkhPrimary)
                    .disabled(!canWithdraw)
                }

                HStack(spacing: 8) {
                    Button {
                        walletManager.blockCloakAction(.partialWithdraw)
                    } label: {
                        Label("Partial Withdraw Locked", systemImage: "lock")
                    }
                    .buttonStyle(.gorkhSecondary)

                    Button {
                        walletManager.blockCloakAction(.privateTransfer)
                    } label: {
                        Label("Shielded Transfer Locked", systemImage: "lock")
                    }
                    .buttonStyle(.gorkhSecondary)
                }

                Text("Partial withdraw remains locked until deposit/withdraw smoke and scan reconciliation are validated.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            }
            .onAppear(perform: syncDefaultSelection)
            .onChange(of: walletManager.cloakPrivateRecords) {
                syncDefaultSelection()
            }
        }
    }

    private var availableRecords: [CloakPrivateRecordMetadata] {
        walletManager.cloakPrivateRecords.filter { $0.state == .deposited }
    }

    private var selectedRecord: CloakPrivateRecordMetadata? {
        guard let id = UUID(uuidString: selectedRecordID) else {
            return nil
        }
        return availableRecords.first { $0.id == id }
    }

    private var approvalControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Approval")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(GorkhColors.secondaryText)

            TextField(TransactionApprovalPolicy.requiredMainnetConfirmation, text: $mainnetConfirmation)
                .textFieldStyle(.roundedBorder)

            Toggle("I reviewed the Cloak full-withdraw fee and net recipient amount.", isOn: $feeAcknowledged)
            Toggle("I completed the Shield review and understand this spends local private state.", isOn: $shieldReviewCompleted)
            Toggle("I explicitly approve this real mainnet Cloak private pay / full withdraw.", isOn: $explicitApproval)
        }
    }

    private func recordSummary(_ record: CloakPrivateRecordMetadata) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], alignment: .leading, spacing: 8) {
            metric("Gross private amount", value: record.amountSOLText)
            metric("Withdraw fee", value: withdrawFeeText(for: record))
            metric("Recipient net estimate", value: withdrawNetText(for: record))
            metric("Commitment", value: record.shortCommitment)
            metric("Leaf", value: record.leafIndex.map(String.init) ?? "Unavailable")
            metric("Deposited", value: record.createdAt.formatted(date: .abbreviated, time: .shortened))
            metric("Deposit tx", value: record.depositSignature?.shortAddress ?? "Unavailable")
            metric("Mint", value: record.mintAddress.shortAddress)
        }
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(GorkhColors.primaryText)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func withdrawFeeText(for record: CloakPrivateRecordMetadata) -> String {
        guard let quote = try? CloakFeeModel.quote(grossLamports: record.amountLamports) else {
            return "Unavailable"
        }
        return quote.totalFeeSOLText
    }

    private func withdrawNetText(for record: CloakPrivateRecordMetadata) -> String {
        guard let quote = try? CloakFeeModel.quote(grossLamports: record.amountLamports) else {
            return "Unavailable"
        }
        return quote.netSOLText
    }

    private func syncDefaultSelection() {
        guard selectedRecord == nil, let first = availableRecords.first else {
            return
        }
        selectedRecordID = first.id.uuidString
    }

    private var canWithdraw: Bool {
        selectedRecord != nil
            && recipientAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && walletManager.selectedNetwork == .mainnetBeta
            && mainnetConfirmation == TransactionApprovalPolicy.requiredMainnetConfirmation
            && feeAcknowledged
            && shieldReviewCompleted
            && explicitApproval
            && !walletManager.isBusy
    }
}
