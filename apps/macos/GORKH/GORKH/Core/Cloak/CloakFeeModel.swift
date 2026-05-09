import Foundation

enum CloakFeeError: LocalizedError, Equatable {
    case amountBelowMinimum(requiredLamports: UInt64)
    case feeOverflow
    case netAmountUnavailable

    var errorDescription: String? {
        switch self {
        case .amountBelowMinimum(let requiredLamports):
            return "Cloak SOL deposits require at least \(requiredLamports) lamports."
        case .feeOverflow:
            return "Cloak fee calculation overflowed."
        case .netAmountUnavailable:
            return "Cloak fee is greater than or equal to the gross amount."
        }
    }
}

enum CloakFeeModel {
    static func calculateCloakSolFeeLamports(gross: UInt64) throws -> UInt64 {
        let multiplied = gross.multipliedReportingOverflow(by: CloakConstants.variableFeeNumerator)
        guard !multiplied.overflow else {
            throw CloakFeeError.feeOverflow
        }

        let variableFee = multiplied.partialValue / CloakConstants.variableFeeDenominator
        let total = CloakConstants.fixedFeeLamports.addingReportingOverflow(variableFee)
        guard !total.overflow else {
            throw CloakFeeError.feeOverflow
        }

        return total.partialValue
    }

    static func calculateCloakSolNetLamports(gross: UInt64) throws -> UInt64 {
        let fee = try calculateCloakSolFeeLamports(gross: gross)
        guard gross > fee else {
            throw CloakFeeError.netAmountUnavailable
        }
        return gross - fee
    }

    static func validateMinimumDeposit(_ amountLamports: UInt64) throws {
        guard amountLamports >= CloakConstants.minimumDepositLamports else {
            throw CloakFeeError.amountBelowMinimum(requiredLamports: CloakConstants.minimumDepositLamports)
        }
    }

    static func quote(grossLamports: UInt64) throws -> CloakFeeQuote {
        try validateMinimumDeposit(grossLamports)
        let variableFee = try variableFeeLamports(gross: grossLamports)
        let totalFee = try calculateCloakSolFeeLamports(gross: grossLamports)
        let netLamports = try calculateCloakSolNetLamports(gross: grossLamports)

        return CloakFeeQuote(
            grossLamports: grossLamports,
            fixedFeeLamports: CloakConstants.fixedFeeLamports,
            variableFeeLamports: variableFee,
            totalFeeLamports: totalFee,
            netLamports: netLamports,
            minimumDepositLamports: CloakConstants.minimumDepositLamports
        )
    }

    private static func variableFeeLamports(gross: UInt64) throws -> UInt64 {
        let multiplied = gross.multipliedReportingOverflow(by: CloakConstants.variableFeeNumerator)
        guard !multiplied.overflow else {
            throw CloakFeeError.feeOverflow
        }
        return multiplied.partialValue / CloakConstants.variableFeeDenominator
    }
}
