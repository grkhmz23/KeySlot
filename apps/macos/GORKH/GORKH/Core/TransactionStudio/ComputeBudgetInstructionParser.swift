import Foundation

enum ComputeBudgetInstructionParser {
    private static let highComputeUnitLimit: UInt32 = 1_200_000
    private static let highMicroLamportsPrice: UInt64 = 100_000

    static func parse(data: Data) -> TransactionParsedInstruction {
        guard let discriminator = data.first else {
            return partial(dataLength: data.count)
        }
        switch discriminator {
        case 1:
            guard let bytes = TransactionInstructionParserFormatting.readUInt32LE(data, offset: 1) else {
                return partial(dataLength: data.count)
            }
            return TransactionParsedInstruction(
                status: .recognized,
                action: "Request heap frame",
                details: [.init(label: "Heap bytes", value: "\(bytes)")],
                riskHints: [],
                explanationFragment: "This transaction requests a compute heap frame of \(bytes) bytes."
            )
        case 2:
            guard let units = TransactionInstructionParserFormatting.readUInt32LE(data, offset: 1) else {
                return partial(dataLength: data.count)
            }
            return TransactionParsedInstruction(
                status: .recognized,
                action: "Set compute unit limit \(units)",
                details: [.init(label: "Compute unit limit", value: "\(units)")],
                riskHints: units >= highComputeUnitLimit ? ["High compute unit limit"] : [],
                explanationFragment: "This transaction sets a compute unit limit of \(units)."
            )
        case 3:
            guard let price = TransactionInstructionParserFormatting.readUInt64LE(data, offset: 1) else {
                return partial(dataLength: data.count)
            }
            return TransactionParsedInstruction(
                status: .recognized,
                action: "Set compute unit price",
                details: [.init(label: "Micro-lamports per CU", value: "\(price)")],
                riskHints: price >= highMicroLamportsPrice ? ["High compute unit price"] : [],
                explanationFragment: "This transaction sets a compute unit price of \(price) micro-lamports."
            )
        default:
            return partial(dataLength: data.count)
        }
    }

    private static func partial(dataLength: Int) -> TransactionParsedInstruction {
        TransactionParsedInstruction(
            status: .partial,
            action: "Compute budget instruction",
            details: [.init(label: "Raw data", value: "\(dataLength) byte(s)")],
            riskHints: [],
            explanationFragment: "This transaction adjusts compute budget settings."
        )
    }
}
