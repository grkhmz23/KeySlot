import Foundation

enum TransactionAccountWatchListBuilder {
    static func build(decoded: DecodedTransaction, maxCount: Int = TransactionAccountWatchList.defaultLimit) -> TransactionAccountWatchList {
        var watches: [TransactionAccountWatch] = []

        func append(address: String?, reason: String, isSigner: Bool = false, isWritable: Bool = false) {
            guard let address, SolanaAddressValidator.isValidAddress(address) else {
                return
            }
            if watches.contains(where: { $0.address == address }) {
                return
            }
            watches.append(TransactionAccountWatch(address: address, reason: reason, isSigner: isSigner, isWritable: isWritable))
        }

        append(address: decoded.feePayer, reason: "Fee payer", isSigner: true, isWritable: true)
        for signer in decoded.signerSummaries {
            append(address: signer.address, reason: signer.isFeePayer ? "Fee payer signer" : "Required signer", isSigner: true, isWritable: false)
        }
        for account in decoded.accountMetas where account.isWritable {
            append(address: account.address, reason: account.isSigner ? "Writable signer" : "Writable account", isSigner: account.isSigner, isWritable: true)
        }
        for instruction in decoded.instructions {
            for account in instruction.accounts where account.isWritable {
                append(address: account.address, reason: "Writable instruction account", isSigner: account.isSigner, isWritable: true)
            }
        }

        let truncated = watches.count > maxCount
        return TransactionAccountWatchList(
            accounts: Array(watches.prefix(maxCount)),
            maxCount: maxCount,
            truncated: truncated
        )
    }
}
