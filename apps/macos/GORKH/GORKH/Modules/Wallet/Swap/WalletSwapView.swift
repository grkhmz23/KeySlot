import SwiftUI

struct WalletSwapView: View {
    @EnvironmentObject private var walletManager: WalletManager
    @State private var inputMint = SwapConstants.nativeSolMint
    @State private var outputMintText = "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v"
    @State private var outputDecimalsText = "6"
    @State private var amountText = ""
    @State private var slippageText = "0.5"
    @State private var mainnetConfirmation = ""
    @State private var completedDevnetSmoke = false
    @State private var showingPopularTokens = false

    private var effectiveSlippageBps: Int {
        let pct = Double(slippageText.replacingOccurrences(of: ",", with: ".")) ?? 0.5
        let bps = Int(pct * 100)
        return max(1, min(5000, bps))
    }

    private var effectiveOutputMint: String {
        outputMintText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var knownOutputToken: TokenMetadata? {
        walletManager.swapOutputTokenOptions.first { $0.mintAddress == effectiveOutputMint }
    }

    private var effectiveOutputDecimals: UInt8? {
        if effectiveOutputMint == SwapConstants.nativeSolMint {
            return 9
        }
        if let known = knownOutputToken {
            return known.decimals
        }
        return UInt8(outputDecimalsText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GorkhPanel("Swap") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        GorkhStatusChip(title: walletManager.selectedNetwork.displayName, systemImage: "network", color: walletManager.selectedNetwork.isMainnet ? GorkhColors.warning : GorkhColors.accent)
                        GorkhStatusChip(title: "Native signer", systemImage: "signature", color: GorkhColors.accent)
                    }

                    Text("Swap via Jupiter. Paste any SPL token address or pick a popular token.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)

                    if !walletManager.selectedNetwork.isMainnet {
                        Text("Jupiter routing is mainnet-oriented. Devnet swaps are not executed.")
                            .font(.caption)
                            .foregroundStyle(GorkhColors.warning)
                    }

                    HStack(alignment: .top, spacing: 12) {
                        SwapTokenSelectorView(
                            title: "Sell",
                            selection: $inputMint,
                            tokenOptions: walletManager.swapInputTokenOptions
                        )

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Amount")
                                .font(.caption)
                                .foregroundStyle(GorkhColors.secondaryText)
                            TextField("0.0", text: $amountText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 140)
                            Text(inputBalanceText)
                                .font(.caption2)
                                .foregroundStyle(GorkhColors.secondaryText)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Buy (mint address)")
                                .font(.caption)
                                .foregroundStyle(GorkhColors.secondaryText)

                            HStack(spacing: 6) {
                                TextField("Contract address", text: $outputMintText)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))

                                Button {
                                    if let pasted = NSPasteboard.general.string(forType: .string) {
                                        outputMintText = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
                                    }
                                } label: {
                                    Image(systemName: "doc.on.clipboard")
                                }
                                .buttonStyle(.bordered)
                                .help("Paste from clipboard")

                                Menu {
                                    ForEach(walletManager.swapOutputTokenOptions) { token in
                                        Button {
                                            outputMintText = token.mintAddress
                                            if let decimals = token.decimals {
                                                outputDecimalsText = "\(decimals)"
                                            }
                                        } label: {
                                            Text("\(token.symbol) — \(token.name)")
                                        }
                                    }
                                } label: {
                                    Image(systemName: "chevron.down")
                                }
                                .menuStyle(.borderedButton)
                                .help("Popular tokens")
                            }

                            HStack(spacing: 8) {
                                if let token = knownOutputToken {
                                    GorkhStatusChip(title: token.symbol, systemImage: "checkmark.circle", color: GorkhColors.success)
                                    Text(token.name)
                                        .font(.caption2)
                                        .foregroundStyle(GorkhColors.secondaryText)
                                } else if SolanaAddressValidator.isValidAddress(effectiveOutputMint) {
                                    GorkhStatusChip(title: "Unknown token", systemImage: "questionmark.circle", color: GorkhColors.warning)
                                }

                                if knownOutputToken == nil {
                                    Text("Decimals:")
                                        .font(.caption2)
                                        .foregroundStyle(GorkhColors.secondaryText)
                                    TextField("6", text: $outputDecimalsText)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 50)
                                }
                            }

                            if !effectiveOutputMint.isEmpty && !SolanaAddressValidator.isValidAddress(effectiveOutputMint) {
                                Text("Invalid Solana address")
                                    .font(.caption2)
                                    .foregroundStyle(GorkhColors.danger)
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Slippage (%)")
                                .font(.caption)
                                .foregroundStyle(GorkhColors.secondaryText)
                            TextField("0.5", text: $slippageText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                            Text("\(effectiveSlippageBps) bps")
                                .font(.caption2)
                                .foregroundStyle(GorkhColors.secondaryText)
                        }

                        Spacer()
                    }

                    HStack {
                        Button {
                            Task {
                                await walletManager.refreshBalance()
                                await walletManager.refreshTokenBalances()
                                normalizeInputSelection()
                            }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.keyslotSecondary)
                        .disabled(walletManager.isBusy)

                        Button {
                            Task {
                                await walletManager.requestSwapQuote(
                                    inputMint: inputMint,
                                    outputMint: effectiveOutputMint,
                                    amountText: amountText,
                                    slippageBps: effectiveSlippageBps
                                )
                            }
                        } label: {
                            Label("Get Quote", systemImage: "chart.line.uptrend.xyaxis")
                        }
                        .buttonStyle(.keyslotPrimary)
                        .disabled(!canRequestQuote)

                        Button {
                            Task { await walletManager.buildCurrentSwapTransaction() }
                        } label: {
                            Label("Build & Review", systemImage: "doc.text.magnifyingglass")
                        }
                        .buttonStyle(.keyslotSecondary)
                        .disabled(walletManager.currentSwapQuote == nil || walletManager.isBusy)

                        Button {
                            Task { await walletManager.simulateCurrentSwap() }
                        } label: {
                            Label("Simulate", systemImage: "waveform.path.ecg")
                        }
                        .buttonStyle(.keyslotSecondary)
                        .disabled(walletManager.currentSwapReview?.canApprove != true || walletManager.isBusy)

                        Spacer()
                    }

                    if let error = walletManager.swapErrorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(GorkhColors.warning)
                    }
                }
            }

            SwapQuoteView(quote: walletManager.currentSwapQuote, inputDecimals: selectedInput?.decimals, outputDecimals: effectiveOutputDecimals)
            SwapReviewView(review: walletManager.currentSwapReview)
            SwapApprovalView(
                quote: walletManager.currentSwapQuote,
                review: walletManager.currentSwapReview,
                simulation: walletManager.swapSimulationResult,
                approvalState: walletManager.swapApprovalState,
                network: walletManager.selectedNetwork,
                mainnetConfirmation: $mainnetConfirmation,
                completedDevnetSmoke: $completedDevnetSmoke,
                approveAction: {
                    Task {
                        await walletManager.approveAndSendSwap(
                            mainnetConfirmation: mainnetConfirmation,
                            hasCompletedDevnetSmoke: completedDevnetSmoke
                        )
                    }
                },
                canApprove: canApprove
            )
            SwapResultView(
                signature: walletManager.lastSwapSignature,
                confirmationStatus: walletManager.lastSwapConfirmationStatus,
                explorerURL: walletManager.explorerURLForLastSwapSignature,
                balanceDeltaVerification: walletManager.swapBalanceDeltaVerification
            )
        }
        .onAppear {
            normalizeInputSelection()
        }
        .onChange(of: walletManager.swapInputTokenOptions) { _, _ in
            normalizeInputSelection()
        }
    }

    private var selectedInput: SwapTokenOption? {
        walletManager.swapInputTokenOptions.first { $0.mintAddress == inputMint }
    }

    private var inputBalanceText: String {
        guard let selectedInput else {
            return "No input balance loaded"
        }
        return "Available \(selectedInput.uiAmountString) \(selectedInput.symbol)"
    }

    private var canRequestQuote: Bool {
        walletManager.selectedProfile?.canSign == true
            && !amountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && SolanaAddressValidator.isValidAddress(effectiveOutputMint)
            && selectedInput?.canUseAsInput == true
            && !walletManager.isBusy
    }

    private var canApprove: Bool {
        guard let quote = walletManager.currentSwapQuote else {
            return false
        }
        return walletManager.selectedNetwork.isMainnet
            ? mainnetConfirmation == TransactionApprovalPolicy.requiredMainnetConfirmation
                && completedDevnetSmoke
                && walletManager.swapSimulationResult?.status == .success
                && walletManager.currentSwapReview?.canApprove == true
                && walletManager.vaultState == .unlocked
                && !quote.isStale()
            : walletManager.swapSimulationResult?.status == .success
                && walletManager.currentSwapReview?.canApprove == true
                && walletManager.vaultState == .unlocked
                && !quote.isStale()
    }

    private func normalizeInputSelection() {
        if !walletManager.swapInputTokenOptions.contains(where: { $0.mintAddress == inputMint }),
           let first = walletManager.swapInputTokenOptions.first {
            inputMint = first.mintAddress
        }
    }
}
