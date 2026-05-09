import CryptoKit
import Foundation

struct SwapTransactionAccountSummary: Codable, Equatable, Identifiable {
    var id: String { address }

    let address: String
    let isSigner: Bool
    let isWritable: Bool
}

struct SwapInstructionProgramSummary: Codable, Equatable, Identifiable {
    var id: String { "\(programID):\(instructionCount)" }

    let programID: String
    let label: String
    let instructionCount: Int
}

struct SwapTransactionReview: Codable, Equatable {
    let transactionVersion: String
    let feePayer: String?
    let signerAccounts: [String]
    let writableAccounts: [String]
    let programSummaries: [SwapInstructionProgramSummary]
    let accountSummaries: [SwapTransactionAccountSummary]
    let requiredSignatureCount: Int
    let messageBase64: String
    let transactionFingerprint: String
    let warnings: [String]
    let blockingReasons: [String]

    var canApprove: Bool {
        blockingReasons.isEmpty
    }
}

struct DecodedSolanaTransaction: Equatable {
    let originalData: Data
    let signatureCount: Int
    let signaturesOffset: Int
    let messageOffset: Int
    let messageData: Data
    let version: String
    let requiredSignatures: Int
    let readonlySignedAccounts: Int
    let readonlyUnsignedAccounts: Int
    let accountKeys: [String]
    let instructionProgramIndexes: [Int]
}

enum SwapTransactionReviewError: LocalizedError, Equatable {
    case invalidBase64
    case invalidShortVector
    case truncated
    case unsupportedVersion(Int)
    case invalidPublicKey
    case signerNotFound

    var errorDescription: String? {
        switch self {
        case .invalidBase64:
            return "Swap transaction is not valid base64."
        case .invalidShortVector:
            return "Swap transaction has an invalid compact vector."
        case .truncated:
            return "Swap transaction is truncated."
        case .unsupportedVersion(let version):
            return "Unsupported Solana transaction version \(version)."
        case .invalidPublicKey:
            return "Swap transaction contains an invalid public key."
        case .signerNotFound:
            return "Selected wallet is not a required signer for this swap transaction."
        }
    }
}

enum SwapTransactionReviewer {
    static func review(serializedTransactionBase64: String, expectedWallet: String) throws -> SwapTransactionReview {
        let decoded = try SolanaSerializedTransaction.decode(base64: serializedTransactionBase64)
        var warnings: [String] = []
        var blockingReasons: [String] = []

        if decoded.feePayer != expectedWallet {
            blockingReasons.append("Fee payer does not match the selected wallet.")
        }
        if !decoded.signerAccounts.contains(expectedWallet) {
            blockingReasons.append("Selected wallet is not a required signer.")
        }
        if decoded.requiredSignatures != 1 {
            warnings.append("Transaction requires \(decoded.requiredSignatures) signatures.")
        }

        let unknownPrograms = decoded.programSummaries.filter { $0.label == "Unknown program" }
        if !unknownPrograms.isEmpty {
            warnings.append("Transaction references \(unknownPrograms.count) unrecognized program id(s). Review route labels carefully.")
        }

        return SwapTransactionReview(
            transactionVersion: decoded.version,
            feePayer: decoded.feePayer,
            signerAccounts: decoded.signerAccounts,
            writableAccounts: decoded.writableAccounts,
            programSummaries: decoded.programSummaries,
            accountSummaries: decoded.accountSummaries,
            requiredSignatureCount: decoded.requiredSignatures,
            messageBase64: decoded.messageData.base64EncodedString(),
            transactionFingerprint: SwapFingerprint.transactionFingerprint(base64: serializedTransactionBase64),
            warnings: warnings,
            blockingReasons: blockingReasons
        )
    }
}

enum SolanaSerializedTransaction {
    static func decode(base64: String) throws -> DecodedSolanaTransaction {
        guard let data = Data(base64Encoded: base64) else {
            throw SwapTransactionReviewError.invalidBase64
        }
        var cursor = 0
        let signatureCount = try readShortVector(data, cursor: &cursor)
        let signaturesOffset = cursor
        let signatureBytes = signatureCount * 64
        guard cursor + signatureBytes <= data.count else {
            throw SwapTransactionReviewError.truncated
        }
        cursor += signatureBytes
        let messageOffset = cursor
        guard cursor < data.count else {
            throw SwapTransactionReviewError.truncated
        }
        let messageData = data.subdata(in: messageOffset..<data.count)
        let firstMessageByte = data[cursor]
        let version: String
        if firstMessageByte & 0x80 == 0 {
            version = "legacy"
        } else {
            let versionNumber = Int(firstMessageByte & 0x7f)
            guard versionNumber == 0 else {
                throw SwapTransactionReviewError.unsupportedVersion(versionNumber)
            }
            version = "v0"
            cursor += 1
        }

        guard cursor + 3 <= data.count else {
            throw SwapTransactionReviewError.truncated
        }
        let requiredSignatures = Int(data[cursor])
        let readonlySigned = Int(data[cursor + 1])
        let readonlyUnsigned = Int(data[cursor + 2])
        cursor += 3

        let accountCount = try readShortVector(data, cursor: &cursor)
        var accountKeys: [String] = []
        accountKeys.reserveCapacity(accountCount)
        for _ in 0..<accountCount {
            guard cursor + 32 <= data.count else {
                throw SwapTransactionReviewError.truncated
            }
            accountKeys.append(Base58.encode(data.subdata(in: cursor..<(cursor + 32))))
            cursor += 32
        }

        guard cursor + 32 <= data.count else {
            throw SwapTransactionReviewError.truncated
        }
        cursor += 32

        let instructionCount = try readShortVector(data, cursor: &cursor)
        var programIndexes: [Int] = []
        for _ in 0..<instructionCount {
            guard cursor < data.count else {
                throw SwapTransactionReviewError.truncated
            }
            programIndexes.append(Int(data[cursor]))
            cursor += 1
            let accountIndexCount = try readShortVector(data, cursor: &cursor)
            guard cursor + accountIndexCount <= data.count else {
                throw SwapTransactionReviewError.truncated
            }
            cursor += accountIndexCount
            let instructionDataLength = try readShortVector(data, cursor: &cursor)
            guard cursor + instructionDataLength <= data.count else {
                throw SwapTransactionReviewError.truncated
            }
            cursor += instructionDataLength
        }

        if version == "v0" {
            let lookupCount = try readShortVector(data, cursor: &cursor)
            for _ in 0..<lookupCount {
                guard cursor + 32 <= data.count else {
                    throw SwapTransactionReviewError.truncated
                }
                cursor += 32
                let writableCount = try readShortVector(data, cursor: &cursor)
                guard cursor + writableCount <= data.count else {
                    throw SwapTransactionReviewError.truncated
                }
                cursor += writableCount
                let readonlyCount = try readShortVector(data, cursor: &cursor)
                guard cursor + readonlyCount <= data.count else {
                    throw SwapTransactionReviewError.truncated
                }
                cursor += readonlyCount
            }
        }

        return DecodedSolanaTransaction(
            originalData: data,
            signatureCount: signatureCount,
            signaturesOffset: signaturesOffset,
            messageOffset: messageOffset,
            messageData: messageData,
            version: version,
            requiredSignatures: requiredSignatures,
            readonlySignedAccounts: readonlySigned,
            readonlyUnsignedAccounts: readonlyUnsigned,
            accountKeys: accountKeys,
            instructionProgramIndexes: programIndexes
        )
    }

    static func sign(base64: String, seed: Data, expectedSigner: String) throws -> String {
        let decoded = try decode(base64: base64)
        guard decoded.signatureCount >= decoded.requiredSignatures,
              let signerIndex = decoded.accountKeys.prefix(decoded.requiredSignatures).firstIndex(of: expectedSigner) else {
            throw SwapTransactionReviewError.signerNotFound
        }
        let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: seed)
        let signature = try privateKey.signature(for: decoded.messageData)
        var data = decoded.originalData
        let signatureOffset = decoded.signaturesOffset + signerIndex * 64
        guard signatureOffset + 64 <= data.count else {
            throw SwapTransactionReviewError.truncated
        }
        data.replaceSubrange(signatureOffset..<(signatureOffset + 64), with: signature)
        return data.base64EncodedString()
    }

    private static func readShortVector(_ data: Data, cursor: inout Int) throws -> Int {
        var result = 0
        var shift = 0
        while true {
            guard cursor < data.count, shift <= 28 else {
                throw SwapTransactionReviewError.invalidShortVector
            }
            let byte = data[cursor]
            cursor += 1
            result |= Int(byte & 0x7f) << shift
            if byte & 0x80 == 0 {
                return result
            }
            shift += 7
        }
    }
}

extension DecodedSolanaTransaction {
    var feePayer: String? {
        accountKeys.first
    }

    var signerAccounts: [String] {
        Array(accountKeys.prefix(requiredSignatures))
    }

    var writableAccounts: [String] {
        accountSummaries.filter(\.isWritable).map(\.address)
    }

    var accountSummaries: [SwapTransactionAccountSummary] {
        accountKeys.enumerated().map { index, address in
            let isSigner = index < requiredSignatures
            let isWritable: Bool
            if isSigner {
                isWritable = index < max(0, requiredSignatures - readonlySignedAccounts)
            } else {
                isWritable = index < max(0, accountKeys.count - readonlyUnsignedAccounts)
            }
            return SwapTransactionAccountSummary(address: address, isSigner: isSigner, isWritable: isWritable)
        }
    }

    var programSummaries: [SwapInstructionProgramSummary] {
        let labels = Dictionary(grouping: instructionProgramIndexes) { programIndex -> String in
            guard programIndex < accountKeys.count else {
                return "Lookup table program"
            }
            return accountKeys[programIndex]
        }
        return labels.map { programID, indexes in
            SwapInstructionProgramSummary(
                programID: programID,
                label: programLabel(programID),
                instructionCount: indexes.count
            )
        }
        .sorted { $0.label < $1.label }
    }

    private func programLabel(_ programID: String) -> String {
        switch programID {
        case SolanaConstants.systemProgramID:
            return "System Program"
        case SolanaConstants.splTokenProgramID:
            return "SPL Token"
        case SolanaConstants.associatedTokenAccountProgramID:
            return "Associated Token Account"
        case SolanaConstants.token2022ProgramID:
            return "Token-2022"
        case "ComputeBudget111111111111111111111111111111":
            return "Compute Budget"
        case "JUP6LkbZbjS1jKKwapdHNy74zcZ3tLUZoi5QNyVTaV4":
            return "Jupiter Aggregator"
        case "JUP4Fb2cqiRUcaTHdrPC8h2gNsA2ETXiPDD33WcGuJB":
            return "Jupiter Aggregator"
        case "MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr":
            return "Memo"
        default:
            return "Unknown program"
        }
    }
}
