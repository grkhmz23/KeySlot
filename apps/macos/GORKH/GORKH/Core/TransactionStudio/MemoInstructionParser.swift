import Foundation

enum MemoInstructionParser {
    private static let maxDisplayedMemoLength = 160

    static func parse(data: Data) -> TransactionParsedInstruction {
        guard let memo = String(data: data, encoding: .utf8) else {
            return TransactionParsedInstruction(
                status: .partial,
                action: "Memo instruction",
                details: [.init(label: "Memo", value: "Non-UTF8 memo data")],
                riskHints: [],
                explanationFragment: "This transaction includes a memo that is not valid UTF-8."
            )
        }

        let displayMemo: String
        let status: TransactionInstructionParseStatus
        if memo.count > maxDisplayedMemoLength {
            displayMemo = "\(memo.prefix(maxDisplayedMemoLength))... [truncated]"
            status = .partial
        } else {
            displayMemo = memo
            status = .recognized
        }

        return TransactionParsedInstruction(
            status: status,
            action: "Memo",
            details: [.init(label: "Memo text", value: displayMemo)],
            riskHints: [],
            explanationFragment: "This transaction includes a memo."
        )
    }
}
