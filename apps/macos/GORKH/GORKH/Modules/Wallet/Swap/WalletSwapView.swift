import SwiftUI

struct WalletSwapView: View {
    @EnvironmentObject private var walletManager: WalletManager
    @State private var inputMint = SwapConstants.nativeSolMint
    @State private var outputMint = "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v"
    @State private var amountText = ""
    @State private var slippageBps = 50
    @State private var mainnetConfirmation = ""
    @State private var completedDevnetSmoke = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GorkhPanel("Jupiter Swap") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        GorkhStatusChip(title: walletManager.selectedNetwork.displayName, systemImage: "network", color: walletManager.selectedNetwork.isMainnet ? GorkhColors.warning : GorkhColors.accent)
                        GorkhStatusChip(title: "Native signer", systemImage: "signature", color: GorkhColors.accent)
                        GorkhStatusChip(title: "No Agent execution", systemImage: "lock", color: GorkhColors.warning)
                    }

                    Text("Swaps use Jupiter public quote/build APIs. GORKH reviews, simulates, and signs locally only after explicit approval.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)

                    if !walletManager.selectedNetwork.isMainnet {
                        Text("Jupiter swap routing is mainnet-oriented. Devnet swaps are not executed or faked.")
                            .font(.caption)
                            .foregroundStyle(GorkhColors.warning)
                    }

                    HStack(alignment: .top, spacing: 12) {
                        SwapTokenSelectorView(
                            title: "Input",
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
                            Text("Output")
                                .font(.caption)
                                .foregroundStyle(GorkhColors.secondaryText)
                            Picker("Output", selection: $outputMint) {
                                ForEach(walletManager.swapOutputTokenOptions) { token in
                                    Text("\(token.symbol) - \(token.name)").tag(token.mintAddress)
                                }
                            }
                            .frame(width: 230)
                            TextField("Manual output mint", text: $outputMint)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.caption, design: .monospaced))
                                .frame(width: 230)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Slippage")
                                .font(.caption)
                                .foregroundStyle(GorkhColors.secondaryText)
                            Picker("Slippage", selection: $slippageBps) {
                                Text("0.1%").tag(10)
                                Text("0.5%").tag(50)
                                Text("1.0%").tag(100)
                                Text("2.0%").tag(200)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 230)
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
                            Label("Refresh Balances", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.gorkhSecondary)
                        .disabled(walletManager.isBusy)

                        Button {
                            Task {
                                await walletManager.requestSwapQuote(
                                    inputMint: inputMint,
                                    outputMint: outputMint,
                                    amountText: amountText,
                                    slippageBps: slippageBps
                                )
                            }
                        } label: {
                            Label("Quote", systemImage: "chart.line.uptrend.xyaxis")
                        }
                        .buttonStyle(.gorkhPrimary)
                        .disabled(!canRequestQuote)

                        Button {
                            Task { await walletManager.buildCurrentSwapTransaction() }
                        } label: {
                            Label("Build & Review", systemImage: "doc.text.magnifyingglass")
                        }
                        .buttonStyle(.gorkhSecondary)
                        .disabled(walletManager.currentSwapQuote == nil || walletManager.isBusy)

                        Button {
                            Task { await walletManager.simulateCurrentSwap() }
                        } label: {
                            Label("Simulate", systemImage: "waveform.path.ecg")
                        }
                        .buttonStyle(.gorkhSecondary)
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

            SwapQuoteView(quote: walletManager.currentSwapQuote, inputDecimals: selectedInput?.decimals, outputDecimals: outputDecimals)
            SwapReviewView(review: walletManager.currentSwapReview)
            SwapApprovalView(
                quote: walletManager.currentSwapQuote,
                review: walletManager.currentSwapReview,
                simulation: walletManager.swapSimulationResult,
                approvalState: walletManager.swapApprovalState,
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
                explorerURL: walletManager.explorerURLForLastSwapSignature
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

    private var outputDecimals: UInt8? {
        if outputMint == SwapConstants.nativeSolMint {
            return 9
        }
        return walletManager.swapOutputTokenOptions.first { $0.mintAddress == outputMint }?.decimals
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
            && SolanaAddressValidator.isValidAddress(outputMint)
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
