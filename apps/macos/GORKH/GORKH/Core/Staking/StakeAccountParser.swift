import Foundation

enum StakeAccountParser {
    static func parseStakeAccounts(
        result: Any,
        profile: WalletProfile,
        network: WalletNetwork,
        currentEpoch: UInt64?,
        fetchedAt: Date = Date()
    ) throws -> [StakeAccountSummary] {
        guard let values = result as? [[String: Any]] else {
            throw SolanaRPCError.invalidResponse
        }

        return values.compactMap { value in
            parseStakeAccount(
                value,
                profile: profile,
                network: network,
                currentEpoch: currentEpoch,
                fetchedAt: fetchedAt
            )
        }
    }

    static func parseStakeAccount(
        _ value: [String: Any],
        profile: WalletProfile,
        network: WalletNetwork,
        currentEpoch: UInt64?,
        fetchedAt: Date = Date()
    ) -> StakeAccountSummary? {
        guard let stakeAccountAddress = value["pubkey"] as? String,
              let account = value["account"] as? [String: Any],
              (account["owner"] as? String) == StakeConstants.stakeProgramID,
              let data = account["data"] as? [String: Any],
              let parsed = data["parsed"] as? [String: Any],
              let parsedType = parsed["type"] as? String,
              let info = parsed["info"] as? [String: Any] else {
            return nil
        }

        let meta = info["meta"] as? [String: Any]
        let authorized = meta?["authorized"] as? [String: Any]
        let staker = authorized?["staker"] as? String
        let withdrawer = authorized?["withdrawer"] as? String
        let stakerMatches = staker == profile.publicAddress
        let withdrawerMatches = withdrawer == profile.publicAddress
        guard stakerMatches || withdrawerMatches else {
            return nil
        }

        let rentExemptReserve = uint64Value(meta?["rentExemptReserve"])
        let stake = info["stake"] as? [String: Any]
        let delegation = stake?["delegation"] as? [String: Any]
        let delegatedLamports = uint64Value(delegation?["stake"]) ?? 0
        let activationEpoch = uint64Value(delegation?["activationEpoch"])
        let deactivationEpoch = uint64Value(delegation?["deactivationEpoch"])
        let voteAccount = delegation?["voter"] as? String
        let state = stateForParsedType(
            parsedType,
            delegatedLamports: delegatedLamports,
            activationEpoch: activationEpoch,
            deactivationEpoch: deactivationEpoch,
            currentEpoch: currentEpoch
        )
        let delegationSummary: StakeDelegationSummary?
        if delegation != nil || delegatedLamports > 0 || voteAccount != nil {
            delegationSummary = StakeDelegationSummary(
                voteAccount: voteAccount,
                delegatedLamports: delegatedLamports,
                activationEpoch: activationEpoch,
                deactivationEpoch: deactivationEpoch,
                state: state
            )
        } else {
            delegationSummary = nil
        }

        let validator = voteAccount.map {
            StakeValidatorSummary(voteAccount: $0, validatorIdentity: nil, name: nil, source: StakeConstants.source)
        }

        return StakeAccountSummary(
            stakeAccountAddress: stakeAccountAddress,
            walletID: profile.id,
            walletLabel: profile.label,
            walletPublicAddress: profile.publicAddress,
            network: network,
            state: state,
            delegation: delegationSummary,
            validator: validator,
            rentExemptReserveLamports: rentExemptReserve,
            stakerAuthorityMatches: stakerMatches,
            withdrawerAuthorityMatches: withdrawerMatches,
            source: StakeConstants.source,
            fetchedAt: fetchedAt,
            errorMessage: nil
        )
    }

    static func stateForParsedType(
        _ parsedType: String,
        delegatedLamports: UInt64,
        activationEpoch: UInt64?,
        deactivationEpoch: UInt64?,
        currentEpoch: UInt64?
    ) -> StakeAccountState {
        switch parsedType.lowercased() {
        case "initialized", "uninitialized":
            return .inactive
        case "delegated":
            guard delegatedLamports > 0 else {
                return .inactive
            }
            if let deactivationEpoch, deactivationEpoch != StakeConstants.deactivationEpochNever {
                if let currentEpoch, deactivationEpoch <= currentEpoch {
                    return .inactive
                }
                return .deactivating
            }
            guard let currentEpoch, let activationEpoch else {
                return .delegated
            }
            return activationEpoch >= currentEpoch ? .activating : .active
        default:
            return .unknown
        }
    }

    private static func uint64Value(_ value: Any?) -> UInt64? {
        if let number = value as? NSNumber {
            return number.uint64Value
        }
        if let int = value as? Int {
            return UInt64(int)
        }
        if let uint = value as? UInt64 {
            return uint
        }
        if let string = value as? String {
            return UInt64(string)
        }
        return nil
    }
}
