import Foundation

enum MarginFiAccountParserError: LocalizedError, Equatable {
    case invalidDataSize(Int)
    case discriminatorMismatch
    case ownerMismatch(String)
    case authorityMismatch(expected: String, actual: String)
    case invalidPublicKey

    var errorDescription: String? {
        switch self {
        case .invalidDataSize(let size):
            return "MarginFi account data size is invalid: \(size)."
        case .discriminatorMismatch:
            return "MarginFi account discriminator does not match the official v2 account discriminator."
        case .ownerMismatch(let owner):
            return "MarginFi account owner is unexpected: \(owner)."
        case .authorityMismatch(let expected, let actual):
            return "MarginFi account authority mismatch. Expected \(expected), got \(actual)."
        case .invalidPublicKey:
            return "MarginFi account contains an invalid public key field."
        }
    }
}

struct MarginFiParsedAccount: Equatable {
    let accountAddress: String
    let groupAddress: String
    let authorityAddress: String
    let accountFlags: UInt64
    let activeBalances: [MarginFiParsedBalance]

    var suppliedPositionCount: Int {
        activeBalances.filter { $0.side == .supplied }.count
    }

    var borrowedPositionCount: Int {
        activeBalances.filter { $0.side == .borrowed }.count
    }

    var unknownPositionCount: Int {
        activeBalances.filter { $0.side == .unknown }.count
    }
}

struct MarginFiParsedBalance: Equatable, Identifiable {
    enum Side: String, Equatable {
        case supplied
        case borrowed
        case unknown
    }

    var id: String { "\(bankAddress):\(side.rawValue):\(slotIndex)" }

    let slotIndex: Int
    let bankAddress: String
    let side: Side
    let bankAssetTag: UInt8
    let tag: UInt16
    let lastUpdate: UInt64
}

enum MarginFiAccountLayout {
    /// Official source: marginfi-v2 type-crate/src/types/user_account.rs.
    static let accountDiscriminator: [UInt8] = [67, 178, 130, 109, 126, 114, 28, 42]
    static let anchorDiscriminatorSize = 8
    static let marginFiAccountSize = 2_304
    static let accountDataSize = anchorDiscriminatorSize + marginFiAccountSize
    static let groupOffset = anchorDiscriminatorSize
    static let authorityOffset = groupOffset + 32
    static let lendingAccountOffset = authorityOffset + 32
    static let balanceSlotCount = 16
    static let balanceSlotSize = 104
    static let accountFlagsOffset = lendingAccountOffset + (balanceSlotCount * balanceSlotSize) + 64

    enum BalanceOffset {
        static let active = 0
        static let bank = 1
        static let bankAssetTag = 33
        static let tag = 34
        static let assetShares = 40
        static let liabilityShares = 56
        static let lastUpdate = 88
    }
}

enum MarginFiAccountParser {
    static func parse(
        account: SolanaProgramAccountData,
        expectedAuthority: String? = nil
    ) throws -> MarginFiParsedAccount {
        guard account.owner == MarginFiConstants.programID else {
            throw MarginFiAccountParserError.ownerMismatch(account.owner)
        }
        return try parse(
            accountAddress: account.publicKey,
            data: account.data,
            expectedAuthority: expectedAuthority
        )
    }

    static func parse(
        accountAddress: String,
        data: Data,
        expectedAuthority: String? = nil
    ) throws -> MarginFiParsedAccount {
        guard data.count == MarginFiAccountLayout.accountDataSize else {
            throw MarginFiAccountParserError.invalidDataSize(data.count)
        }

        let discriminator = Array(data[0..<MarginFiAccountLayout.anchorDiscriminatorSize])
        guard discriminator == MarginFiAccountLayout.accountDiscriminator else {
            throw MarginFiAccountParserError.discriminatorMismatch
        }

        let groupAddress = try publicKey(data, offset: MarginFiAccountLayout.groupOffset)
        let authorityAddress = try publicKey(data, offset: MarginFiAccountLayout.authorityOffset)
        if let expectedAuthority, expectedAuthority != authorityAddress {
            throw MarginFiAccountParserError.authorityMismatch(
                expected: expectedAuthority,
                actual: authorityAddress
            )
        }

        return MarginFiParsedAccount(
            accountAddress: accountAddress,
            groupAddress: groupAddress,
            authorityAddress: authorityAddress,
            accountFlags: try littleEndianUInt64(data, offset: MarginFiAccountLayout.accountFlagsOffset),
            activeBalances: try parseBalances(data)
        )
    }

    private static func parseBalances(_ data: Data) throws -> [MarginFiParsedBalance] {
        try (0..<MarginFiAccountLayout.balanceSlotCount).compactMap { index in
            let offset = MarginFiAccountLayout.lendingAccountOffset + (index * MarginFiAccountLayout.balanceSlotSize)
            let active = data[offset + MarginFiAccountLayout.BalanceOffset.active] != 0
            guard active else {
                return nil
            }

            let bankAddress = try publicKey(data, offset: offset + MarginFiAccountLayout.BalanceOffset.bank)
            let assetShares = data[(offset + MarginFiAccountLayout.BalanceOffset.assetShares)..<(offset + MarginFiAccountLayout.BalanceOffset.assetShares + 16)]
            let liabilityShares = data[(offset + MarginFiAccountLayout.BalanceOffset.liabilityShares)..<(offset + MarginFiAccountLayout.BalanceOffset.liabilityShares + 16)]
            let hasAssetShares = assetShares.contains { $0 != 0 }
            let hasLiabilityShares = liabilityShares.contains { $0 != 0 }
            let side: MarginFiParsedBalance.Side
            switch (hasAssetShares, hasLiabilityShares) {
            case (true, false):
                side = .supplied
            case (false, true):
                side = .borrowed
            default:
                side = .unknown
            }

            return MarginFiParsedBalance(
                slotIndex: index,
                bankAddress: bankAddress,
                side: side,
                bankAssetTag: data[offset + MarginFiAccountLayout.BalanceOffset.bankAssetTag],
                tag: try littleEndianUInt16(data, offset: offset + MarginFiAccountLayout.BalanceOffset.tag),
                lastUpdate: try littleEndianUInt64(data, offset: offset + MarginFiAccountLayout.BalanceOffset.lastUpdate)
            )
        }
    }

    private static func publicKey(_ data: Data, offset: Int) throws -> String {
        guard offset >= 0, offset + 32 <= data.count else {
            throw MarginFiAccountParserError.invalidDataSize(data.count)
        }
        return Base58.encode(data.subdata(in: offset..<(offset + 32)))
    }

    private static func littleEndianUInt16(_ data: Data, offset: Int) throws -> UInt16 {
        guard offset >= 0, offset + 2 <= data.count else {
            throw MarginFiAccountParserError.invalidDataSize(data.count)
        }
        return data[offset..<(offset + 2)].enumerated().reduce(UInt16(0)) { partial, element in
            partial | (UInt16(element.element) << (element.offset * 8))
        }
    }

    private static func littleEndianUInt64(_ data: Data, offset: Int) throws -> UInt64 {
        guard offset >= 0, offset + 8 <= data.count else {
            throw MarginFiAccountParserError.invalidDataSize(data.count)
        }
        return data[offset..<(offset + 8)].enumerated().reduce(UInt64(0)) { partial, element in
            partial | (UInt64(element.element) << (element.offset * 8))
        }
    }
}
