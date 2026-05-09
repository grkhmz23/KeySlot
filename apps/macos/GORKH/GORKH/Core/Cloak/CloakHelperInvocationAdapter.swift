import Foundation

enum CloakHelperInvocationError: LocalizedError, Equatable {
    case disabled
    case commandNotAllowlisted(CloakBridgeCommand)
    case invalidProgramID
    case missingAmount
    case helperRejected(String)
    case responseRejected(String)

    var errorDescription: String? {
        switch self {
        case .disabled:
            return "Cloak helper invocation is disabled by default."
        case .commandNotAllowlisted(let command):
            return "Cloak helper command is not allowlisted: \(command.rawValue)."
        case .invalidProgramID:
            return "Cloak bridge request program id does not match the allowlisted program."
        case .missingAmount:
            return "Deposit plan dry-run requires an amount."
        case .helperRejected(let message):
            return message
        case .responseRejected(let message):
            return "Cloak helper response rejected: \(message)"
        }
    }
}

struct CloakHelperInvocationAdapter {
    let policy: CloakBridgeExecutionPolicy
    let projectRoot: URL?
    let pathResolver: any CloakHelperPathResolving
    let processRunner: any CloakHelperProcessRunning

    static func disabled() -> CloakHelperInvocationAdapter {
        CloakHelperInvocationAdapter(
            policy: .disabled,
            projectRoot: nil,
            pathResolver: CloakHelperPathResolver(),
            processRunner: CloakHelperDirectProcessRunner()
        )
    }

    var status: CloakHelperInvocationStatus {
        policy.helperExecutionEnabled ? .dryRunEnabled : .disabled
    }

    func invoke(_ request: CloakBridgeRequest) async -> CloakBridgeResponse {
        do {
            try validateRequest(request)
            guard policy.helperExecutionEnabled else {
                throw CloakHelperInvocationError.disabled
            }

            let resolvedPath = try pathResolver.resolve(policy: policy, projectRoot: projectRoot)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let stdin = try encoder.encode(request)
            let result = try await processRunner.run(
                resolvedPath: resolvedPath,
                command: request.command,
                stdin: stdin
            )

            guard result.exitCode == 0 else {
                throw CloakHelperInvocationError.helperRejected(result.stderr)
            }
            try CloakBridgeContractValidator.validate(jsonData: result.stdout)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let response = try decoder.decode(CloakBridgeResponse.self, from: result.stdout)
            try validateResponse(response, for: request)
            return response
        } catch {
            return lockedResponse(for: request, error: error)
        }
    }

    private func validateRequest(_ request: CloakBridgeRequest) throws {
        try CloakBridgeContractValidator.validate(request)
        guard request.programID == CloakConstants.programID else {
            throw CloakHelperInvocationError.invalidProgramID
        }
        guard policy.allowedCommands.contains(request.command),
              request.command.isHelperCommandAllowedInPhase25 else {
            throw CloakHelperInvocationError.commandNotAllowlisted(request.command)
        }
        if request.command == .depositPlan {
            guard let amountLamports = request.amountLamports else {
                throw CloakHelperInvocationError.missingAmount
            }
            _ = try CloakFeeModel.quote(grossLamports: amountLamports)
        }
    }

    private func validateResponse(_ response: CloakBridgeResponse, for request: CloakBridgeRequest) throws {
        try CloakBridgeContractValidator.validate(response)
        guard response.command == request.command else {
            throw CloakHelperInvocationError.responseRejected("command mismatch")
        }
        guard response.programID == CloakConstants.programID else {
            throw CloakHelperInvocationError.responseRejected("program id mismatch")
        }
        guard response.transactionSignature == nil, response.commitmentPrefix == nil else {
            throw CloakHelperInvocationError.responseRejected("future execution identifiers are not accepted in dry-run mode")
        }
        if let sdkValidation = response.sdkValidation {
            guard sdkValidation.expectedProgramID == CloakConstants.programID else {
                throw CloakHelperInvocationError.responseRejected("SDK expected program id mismatch")
            }
        }
    }

    private func lockedResponse(for request: CloakBridgeRequest, error: Error) -> CloakBridgeResponse {
        let category: CloakBridgeErrorCategory
        switch error {
        case CloakHelperInvocationError.disabled,
             CloakHelperPathError.helperExecutionDisabled:
            category = .lockedInPhase23
        case CloakHelperInvocationError.commandNotAllowlisted:
            category = .unsupportedCommand
        case CloakBridgeValidationError.forbiddenField:
            category = .forbiddenField
        case CloakHelperPathError.nodeExecutableUnavailable,
             CloakHelperPathError.projectRootMissing:
            category = .helperUnavailable
        default:
            category = .invalidRequest
        }

        return CloakBridgeResponse(
            requestID: request.id,
            command: request.command,
            actionKind: request.actionKind,
            status: category == .helperUnavailable ? .unavailable : .locked,
            errorCategory: category,
            message: error.localizedDescription
        )
    }
}
