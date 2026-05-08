import CryptoKit
import Foundation

struct ProgramDerivedAddressResult: Equatable {
    let address: Data
    let bump: UInt8

    var base58Address: String {
        Base58.encode(address)
    }
}

enum ProgramDerivedAddressError: LocalizedError, Equatable {
    case maxSeedLengthExceeded
    case invalidProgramID
    case invalidSeeds
    case unableToFindAddress

    var errorDescription: String? {
        switch self {
        case .maxSeedLengthExceeded:
            return "PDA derivation supports at most 16 seeds, each no longer than 32 bytes."
        case .invalidProgramID:
            return "PDA program ID is invalid."
        case .invalidSeeds:
            return "PDA seeds produced an on-curve address."
        case .unableToFindAddress:
            return "Unable to find a valid program-derived address."
        }
    }
}

enum ProgramDerivedAddress {
    private static let maxSeeds = 16
    private static let maxSeedLength = 32
    private static let marker = Data("ProgramDerivedAddress".utf8)

    static func createProgramAddress(seeds: [Data], programID: String) throws -> Data {
        guard seeds.count <= maxSeeds, seeds.allSatisfy({ $0.count <= maxSeedLength }) else {
            throw ProgramDerivedAddressError.maxSeedLengthExceeded
        }
        guard let program = SolanaAddressValidator.decodeAddress(programID) else {
            throw ProgramDerivedAddressError.invalidProgramID
        }

        var hasher = SHA256()
        seeds.forEach { hasher.update(data: $0) }
        hasher.update(data: program)
        hasher.update(data: marker)

        let digest = Data(hasher.finalize())
        guard !Ed25519CompressedPoint.isOnCurve(digest) else {
            throw ProgramDerivedAddressError.invalidSeeds
        }

        return digest
    }

    static func findProgramAddress(seeds: [Data], programID: String) throws -> ProgramDerivedAddressResult {
        for bump in stride(from: 255, through: 0, by: -1) {
            let bumpSeed = Data([UInt8(bump)])
            if let address = try? createProgramAddress(seeds: seeds + [bumpSeed], programID: programID) {
                return ProgramDerivedAddressResult(address: address, bump: UInt8(bump))
            }
        }

        throw ProgramDerivedAddressError.unableToFindAddress
    }
}

enum Ed25519CompressedPoint {
    static func isOnCurve(_ compressedPoint: Data) -> Bool {
        guard compressedPoint.count == 32 else {
            return false
        }

        var yBytes = [UInt8](compressedPoint)
        yBytes[31] &= 0x7f

        let yRaw = FieldBigUInt(littleEndianBytes: Data(yBytes))
        guard yRaw < Ed25519FieldElement.modulus else {
            return false
        }

        let y = Ed25519FieldElement(yRaw)
        let ySquared = y * y
        let numerator = ySquared - .one
        let denominator = Ed25519FieldElement.curveD * ySquared + .one
        guard !denominator.isZero else {
            return false
        }

        let xSquared = numerator * denominator.inverted()
        return xSquared.isZero || xSquared.isQuadraticResidue
    }
}

private struct Ed25519FieldElement: Equatable {
    static let modulus = FieldBigUInt(littleEndianBytes: Data([0xed] + Array(repeating: 0xff, count: 30) + [0x7f]))
    static let zero = Ed25519FieldElement(0)
    static let one = Ed25519FieldElement(1)
    static let curveD: Ed25519FieldElement = {
        let numerator = Ed25519FieldElement.zero - Ed25519FieldElement(121_665)
        return numerator * Ed25519FieldElement(121_666).inverted()
    }()

    private static let inverseExponent = modulus - FieldBigUInt(2)
    private static let residueExponent = (modulus - FieldBigUInt(1)).shiftedRight(1)

    let value: FieldBigUInt

    var isZero: Bool {
        value.isZero
    }

    init(_ value: UInt64) {
        self.value = FieldBigUInt(value).reducedEd25519()
    }

    init(_ value: FieldBigUInt) {
        self.value = value.reducedEd25519()
    }

    static func + (lhs: Ed25519FieldElement, rhs: Ed25519FieldElement) -> Ed25519FieldElement {
        Ed25519FieldElement((lhs.value + rhs.value).reducedEd25519())
    }

    static func - (lhs: Ed25519FieldElement, rhs: Ed25519FieldElement) -> Ed25519FieldElement {
        if lhs.value >= rhs.value {
            return Ed25519FieldElement(lhs.value - rhs.value)
        }

        return Ed25519FieldElement((lhs.value + modulus) - rhs.value)
    }

    static func * (lhs: Ed25519FieldElement, rhs: Ed25519FieldElement) -> Ed25519FieldElement {
        Ed25519FieldElement((lhs.value * rhs.value).reducedEd25519())
    }

    func inverted() -> Ed25519FieldElement {
        pow(Self.inverseExponent)
    }

    var isQuadraticResidue: Bool {
        pow(Self.residueExponent) == .one
    }

    private func pow(_ exponent: FieldBigUInt) -> Ed25519FieldElement {
        var result = Ed25519FieldElement.one
        var base = self

        for index in 0..<exponent.bitLength {
            if exponent.bit(at: index) {
                result = result * base
            }
            base = base * base
        }

        return result
    }
}

private struct FieldBigUInt: Equatable, Comparable {
    private var words: [UInt16]

    var isZero: Bool {
        words.isEmpty
    }

    var bitLength: Int {
        guard let last = words.last else {
            return 0
        }
        return (words.count - 1) * 16 + (16 - last.leadingZeroBitCount)
    }

    init(_ value: UInt64) {
        var remaining = value
        var output: [UInt16] = []
        while remaining > 0 {
            output.append(UInt16(remaining & 0xffff))
            remaining >>= 16
        }
        words = output
    }

    init(littleEndianBytes data: Data) {
        var output: [UInt16] = []
        let bytes = [UInt8](data)
        var index = 0

        while index < bytes.count {
            let low = UInt16(bytes[index])
            let high = index + 1 < bytes.count ? UInt16(bytes[index + 1]) << 8 : 0
            output.append(low | high)
            index += 2
        }

        words = Self.normalized(output)
    }

    static func < (lhs: FieldBigUInt, rhs: FieldBigUInt) -> Bool {
        let left = normalized(lhs.words)
        let right = normalized(rhs.words)

        if left.count != right.count {
            return left.count < right.count
        }
        guard !left.isEmpty else {
            return false
        }

        for index in stride(from: left.count - 1, through: 0, by: -1) {
            if left[index] != right[index] {
                return left[index] < right[index]
            }
            if index == 0 {
                break
            }
        }

        return false
    }

    static func + (lhs: FieldBigUInt, rhs: FieldBigUInt) -> FieldBigUInt {
        let count = max(lhs.words.count, rhs.words.count)
        var output: [UInt16] = []
        output.reserveCapacity(count + 1)
        var carry: UInt32 = 0

        for index in 0..<count {
            let left = index < lhs.words.count ? UInt32(lhs.words[index]) : 0
            let right = index < rhs.words.count ? UInt32(rhs.words[index]) : 0
            let total = left + right + carry
            output.append(UInt16(total & 0xffff))
            carry = total >> 16
        }

        if carry > 0 {
            output.append(UInt16(carry))
        }

        return FieldBigUInt(words: output)
    }

    static func - (lhs: FieldBigUInt, rhs: FieldBigUInt) -> FieldBigUInt {
        precondition(lhs >= rhs, "FieldBigUInt subtraction requires lhs >= rhs")
        var output: [UInt16] = []
        output.reserveCapacity(lhs.words.count)
        var borrow: Int32 = 0

        for index in 0..<lhs.words.count {
            let left = Int32(lhs.words[index])
            let right = index < rhs.words.count ? Int32(rhs.words[index]) : 0
            var value = left - right - borrow
            if value < 0 {
                value += 1 << 16
                borrow = 1
            } else {
                borrow = 0
            }
            output.append(UInt16(value))
        }

        return FieldBigUInt(words: output)
    }

    static func * (lhs: FieldBigUInt, rhs: FieldBigUInt) -> FieldBigUInt {
        guard !lhs.isZero, !rhs.isZero else {
            return FieldBigUInt(0)
        }

        var accumulation = [UInt64](repeating: 0, count: lhs.words.count + rhs.words.count)
        for leftIndex in lhs.words.indices {
            for rightIndex in rhs.words.indices {
                accumulation[leftIndex + rightIndex] += UInt64(lhs.words[leftIndex]) * UInt64(rhs.words[rightIndex])
            }
        }

        var output: [UInt16] = []
        output.reserveCapacity(accumulation.count + 2)
        var carry: UInt64 = 0
        for value in accumulation {
            let total = value + carry
            output.append(UInt16(total & 0xffff))
            carry = total >> 16
        }

        while carry > 0 {
            output.append(UInt16(carry & 0xffff))
            carry >>= 16
        }

        return FieldBigUInt(words: output)
    }

    func multiplied(bySmall value: UInt16) -> FieldBigUInt {
        guard value > 0, !isZero else {
            return FieldBigUInt(0)
        }

        var output: [UInt16] = []
        output.reserveCapacity(words.count + 1)
        var carry: UInt32 = 0

        for word in words {
            let total = UInt32(word) * UInt32(value) + carry
            output.append(UInt16(total & 0xffff))
            carry = total >> 16
        }

        while carry > 0 {
            output.append(UInt16(carry & 0xffff))
            carry >>= 16
        }

        return FieldBigUInt(words: output)
    }

    func shiftedRight(_ bitCount: Int) -> FieldBigUInt {
        guard bitCount > 0 else {
            return self
        }

        let wordShift = bitCount / 16
        let bitShift = bitCount % 16
        guard wordShift < words.count else {
            return FieldBigUInt(0)
        }

        var output: [UInt16] = []
        output.reserveCapacity(words.count - wordShift)

        for index in wordShift..<words.count {
            var value = UInt32(words[index]) >> UInt32(bitShift)
            if bitShift > 0, index + 1 < words.count {
                value |= UInt32(words[index + 1]) << UInt32(16 - bitShift)
            }
            output.append(UInt16(value & 0xffff))
        }

        return FieldBigUInt(words: output)
    }

    func lowBits(_ bitCount: Int) -> FieldBigUInt {
        guard bitCount > 0 else {
            return FieldBigUInt(0)
        }
        guard bitCount < bitLength else {
            return self
        }

        let wordsToKeep = (bitCount + 15) / 16
        var output = Array(words.prefix(wordsToKeep))
        let remainingBits = bitCount % 16
        if remainingBits > 0, !output.isEmpty {
            let mask = UInt16((UInt32(1) << UInt32(remainingBits)) - 1)
            output[output.count - 1] &= mask
        }

        return FieldBigUInt(words: output)
    }

    func bit(at index: Int) -> Bool {
        guard index >= 0 else {
            return false
        }

        let wordIndex = index / 16
        let bitIndex = index % 16
        guard wordIndex < words.count else {
            return false
        }

        return (words[wordIndex] & (UInt16(1) << UInt16(bitIndex))) != 0
    }

    func reducedEd25519() -> FieldBigUInt {
        var value = self
        while value.bitLength > 255 {
            let low = value.lowBits(255)
            let high = value.shiftedRight(255).multiplied(bySmall: 19)
            value = low + high
        }

        while value >= Ed25519FieldElement.modulus {
            value = value - Ed25519FieldElement.modulus
        }

        return value
    }

    private init(words: [UInt16]) {
        self.words = Self.normalized(words)
    }

    private static func normalized(_ words: [UInt16]) -> [UInt16] {
        var result = words
        while result.last == 0 {
            result.removeLast()
        }
        return result
    }
}
