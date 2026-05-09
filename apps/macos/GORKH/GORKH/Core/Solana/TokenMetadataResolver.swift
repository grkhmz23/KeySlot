import Foundation

enum TokenMetadataResolver {
    static func resolve(
        balance: TokenBalance,
        network: WalletNetwork,
        mintAccountDecimals: UInt8? = nil
    ) -> ResolvedTokenMetadata {
        let known = TokenMetadataRegistry.lookup(mintAddress: balance.mintAddress, network: network)
        let decimals: UInt8?
        let decimalsSource: TokenMetadataSource

        if let parsedDecimals = balance.decimals {
            decimals = parsedDecimals
            decimalsSource = .parsedAccount
        } else if let knownDecimals = known?.decimals {
            decimals = knownDecimals
            decimalsSource = .knownRegistry
        } else if let mintAccountDecimals {
            decimals = mintAccountDecimals
            decimalsSource = .mintAccount
        } else {
            decimals = nil
            decimalsSource = .unknown
        }

        if let known {
            return ResolvedTokenMetadata(
                mintAddress: balance.mintAddress,
                symbol: known.symbol,
                name: known.name,
                decimals: decimals,
                network: network,
                source: .knownRegistry,
                decimalsSource: decimalsSource,
                warning: known.warning
            )
        }

        return ResolvedTokenMetadata(
            mintAddress: balance.mintAddress,
            symbol: "UNKNOWN",
            name: "Unknown Token",
            decimals: decimals,
            network: network,
            source: .unknown,
            decimalsSource: decimalsSource,
            warning: network == .devnet ? "Unknown devnet token. Verify the mint before sending." : nil
        )
    }

    static func warnings(for balance: TokenBalance, metadata: ResolvedTokenMetadata) -> [TokenWarning] {
        var warnings: [TokenWarning] = []

        if !metadata.isKnown {
            warnings.append(.unknownToken)
        }
        if metadata.network == .devnet {
            warnings.append(.devnetToken)
        }
        if balance.state == .frozen {
            warnings.append(.frozenAccount)
        }
        if balance.delegateAddress != nil {
            warnings.append(.delegatedAccount)
        }
        if balance.closeAuthorityAddress != nil {
            warnings.append(.closeAuthorityPresent)
        }
        if balance.amountRaw == 0 {
            warnings.append(.zeroBalance)
        }
        if metadata.decimals == nil {
            warnings.append(.decimalsUnavailable)
        }
        if balance.programKind == .token2022 {
            warnings.append(.token2022Unsupported)
        }

        return warnings
    }

    static func canSend(balance: TokenBalance, metadata: ResolvedTokenMetadata) -> Bool {
        balance.programKind == .splToken
            && balance.state == .initialized
            && balance.amountRaw > 0
            && !warnings(for: balance, metadata: metadata).contains { $0.blocksSend }
    }
}
