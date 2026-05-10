import Foundation

enum TransactionSimulationDiffBuilder {
    static func build(
        watchList: TransactionAccountWatchList,
        before: [TransactionAccountEnrichment],
        after: [TransactionAccountEnrichment?]
    ) -> TransactionSimulationDiffSummary {
        guard watchList.accounts.isEmpty == false else {
            return .unavailable("No bounded account watchlist was available for simulation diff.")
        }
        guard after.isEmpty == false else {
            return .unavailable("RPC simulation did not return post-simulation account states.")
        }

        let beforeByAddress = Dictionary(uniqueKeysWithValues: before.map { ($0.address, $0) })
        var rows: [TransactionAccountDiff] = []
        for (index, watch) in watchList.accounts.enumerated() {
            let beforeAccount = beforeByAddress[watch.address]
            let afterAccount = index < after.count ? after[index] : nil
            rows.append(diff(address: watch.address, before: beforeAccount, after: afterAccount))
        }

        return TransactionSimulationDiffSummary(status: .available, rows: rows, unavailableReason: nil)
    }

    private static func diff(
        address: String,
        before: TransactionAccountEnrichment?,
        after: TransactionAccountEnrichment?
    ) -> TransactionAccountDiff {
        let lamportsDelta: Int64?
        if let beforeLamports = before?.lamports, let afterLamports = after?.lamports {
            lamportsDelta = Int64(afterLamports) - Int64(beforeLamports)
        } else {
            lamportsDelta = nil
        }

        let tokenDelta: String?
        if let beforeRaw = before?.tokenAmountRaw, let afterRaw = after?.tokenAmountRaw,
           let beforeDecimal = Decimal(string: beforeRaw), let afterDecimal = Decimal(string: afterRaw) {
            tokenDelta = NSDecimalNumber(decimal: afterDecimal - beforeDecimal).stringValue
        } else {
            tokenDelta = nil
        }

        let status: String
        if before == nil, after != nil {
            status = "Created or newly visible"
        } else if before != nil, after == nil {
            status = "Closed or unavailable after simulation"
        } else if lamportsDelta != nil || tokenDelta != nil || before?.ownerProgram != after?.ownerProgram {
            status = "Changed"
        } else {
            status = "No parsed change"
        }

        return TransactionAccountDiff(
            address: address,
            lamportsBefore: before?.lamports,
            lamportsAfter: after?.lamports,
            lamportsDelta: lamportsDelta,
            tokenAmountBefore: before?.tokenAmountRaw,
            tokenAmountAfter: after?.tokenAmountRaw,
            tokenAmountDelta: tokenDelta,
            ownerBefore: before?.ownerProgram,
            ownerAfter: after?.ownerProgram,
            status: status
        )
    }
}
