import Foundation

enum SplTokenParser {
    static func parseTokenAccounts(
        result: Any,
        programKind: TokenProgramKind,
        fetchedAt: Date = Date()
    ) throws -> [TokenBalance] {
        guard let dictionary = result as? [String: Any],
              let values = dictionary["value"] as? [[String: Any]] else {
            throw SolanaRPCError.invalidResponse
        }

        return values.compactMap { value in
            parseTokenAccount(value, programKind: programKind, fetchedAt: fetchedAt)
        }
    }

    static func parseTokenAccount(
        _ value: [String: Any],
        programKind: TokenProgramKind,
        fetchedAt: Date = Date()
    ) -> TokenBalance? {
        guard let tokenAccountAddress = value["pubkey"] as? String,
              let account = value["account"] as? [String: Any],
              (account["owner"] as? String) == programKind.programID,
              let data = account["data"] as? [String: Any],
              let parsed = data["parsed"] as? [String: Any],
              let info = parsed["info"] as? [String: Any],
              let mintAddress = info["mint"] as? String,
              let ownerAddress = info["owner"] as? String,
              let tokenAmount = info["tokenAmount"] as? [String: Any],
              let rawAmountString = tokenAmount["amount"] as? String,
              let rawAmount = UInt64(rawAmountString) else {
            return nil
        }

        let decimals: UInt8?
        if let decimalsNumber = tokenAmount["decimals"] as? NSNumber {
            decimals = UInt8(clamping: decimalsNumber.intValue)
        } else if let decimalsInt = tokenAmount["decimals"] as? Int {
            decimals = UInt8(clamping: decimalsInt)
        } else {
            decimals = nil
        }

        let uiAmountString = tokenAmount["uiAmountString"] as? String
            ?? decimals.map { TokenAmountFormatter.format(rawAmount: rawAmount, decimals: $0) }
            ?? rawAmountString

        let delegatedAmountRaw: UInt64?
        if let delegatedAmount = info["delegatedAmount"] as? [String: Any],
           let amountString = delegatedAmount["amount"] as? String {
            delegatedAmountRaw = UInt64(amountString)
        } else if let amountString = info["delegatedAmount"] as? String {
            delegatedAmountRaw = UInt64(amountString)
        } else {
            delegatedAmountRaw = nil
        }

        return TokenBalance(
            tokenAccountAddress: tokenAccountAddress,
            ownerAddress: ownerAddress,
            mintAddress: mintAddress,
            amountRaw: rawAmount,
            decimals: decimals,
            uiAmountString: uiAmountString,
            programKind: programKind,
            state: TokenAccountState(rawRPCValue: info["state"] as? String),
            delegateAddress: info["delegate"] as? String,
            delegatedAmountRaw: delegatedAmountRaw,
            closeAuthorityAddress: info["closeAuthority"] as? String,
            fetchedAt: fetchedAt
        )
    }
}
