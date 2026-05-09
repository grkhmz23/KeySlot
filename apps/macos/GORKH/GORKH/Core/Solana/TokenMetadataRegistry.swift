import Foundation

enum TokenMetadataRegistry {
    static let knownTokens: [TokenMetadata] = [
        TokenMetadata(
            mintAddress: "So11111111111111111111111111111111111111112",
            symbol: "wSOL",
            name: "Wrapped SOL",
            decimals: 9,
            network: nil,
            warning: nil
        ),
        TokenMetadata(
            mintAddress: "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
            symbol: "USDC",
            name: "USD Coin",
            decimals: 6,
            network: .mainnetBeta,
            warning: nil
        ),
        TokenMetadata(
            mintAddress: "4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU",
            symbol: "USDC",
            name: "USD Coin Devnet",
            decimals: 6,
            network: .devnet,
            warning: "Devnet USDC is for testing only."
        ),
        TokenMetadata(
            mintAddress: "Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB",
            symbol: "USDT",
            name: "Tether USD",
            decimals: 6,
            network: .mainnetBeta,
            warning: nil
        ),
        TokenMetadata(
            mintAddress: "J1toso1uCk3RLmjorhTtrVwY9HJ7X8V9yYac6Y7kGCPn",
            symbol: "JitoSOL",
            name: "Jito Staked SOL",
            decimals: 9,
            network: .mainnetBeta,
            warning: "Liquid staking token. Review protocol risk before sending."
        ),
        TokenMetadata(
            mintAddress: "mSoLzYCxHdYgdzU16g5QSh3i5K3z3KZK7ytfqcJm7So",
            symbol: "mSOL",
            name: "Marinade Staked SOL",
            decimals: 9,
            network: .mainnetBeta,
            warning: "Liquid staking token. Review protocol risk before sending."
        ),
        TokenMetadata(
            mintAddress: "bSo13r4TkiE4KumL71LsHTPpL2euBYLFx6h9HP3piy1",
            symbol: "bSOL",
            name: "BlazeStake Staked SOL",
            decimals: 9,
            network: .mainnetBeta,
            warning: "Liquid staking token. Review protocol risk before sending."
        ),
        TokenMetadata(
            mintAddress: "DezXAZ8z7PnrnRJjz3wXBoRgixCa6xjnB7YaB1pPB263",
            symbol: "BONK",
            name: "Bonk",
            decimals: 5,
            network: .mainnetBeta,
            warning: "Meme token. Verify the mint before sending."
        )
    ]

    static func lookup(mintAddress: String, network: WalletNetwork) -> TokenMetadata? {
        knownTokens.first {
            $0.mintAddress == mintAddress && ($0.network == network || $0.network == nil)
        }
    }
}
