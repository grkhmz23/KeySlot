import CryptoKit
import Foundation

enum CloakExecutionBridgeError: LocalizedError, Equatable {
    case commandNotAllowlisted(CloakBridgeCommand)
    case invalidRequest(String)
    case helperRejected(String)
    case responseRejected(String)
    case signingRejected(String)

    var errorDescription: String? {
        switch self {
        case .commandNotAllowlisted(let command):
            return "Cloak execution command is not allowlisted: \(command.rawValue)."
        case .invalidRequest(let message),
             .helperRejected(let message),
             .responseRejected(let message),
             .signingRejected(let message):
            return message
        }
    }
}

enum CloakBridgeSigningKind: String, Codable, Equatable {
    case signTransaction = "sign_transaction"
    case signMessage = "sign_message"
}

struct CloakBridgeSigningRequest: Codable, Equatable, Identifiable {
    let type: String
    let id: UUID
    let requestID: UUID?
    let signingKind: CloakBridgeSigningKind
    let walletPublicKey: String
    let network: WalletNetwork
    let actionKind: CloakActionKind
    let amountLamports: UInt64
    let mintAddress: String
    let programID: String
    let draftFingerprint: String
    let purpose: String
    let payloadBase64: String
    let timestamp: Date
    let expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case type
        case id
        case requestID = "requestId"
        case signingKind
        case walletPublicKey
        case network
        case actionKind
        case amountLamports
        case mintAddress
        case programID = "programId"
        case draftFingerprint
        case purpose
        case payloadBase64
        case timestamp
        case expiresAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        id = try container.decode(UUID.self, forKey: .id)
        requestID = try container.decodeIfPresent(UUID.self, forKey: .requestID)
        signingKind = try container.decode(CloakBridgeSigningKind.self, forKey: .signingKind)
        walletPublicKey = try container.decode(String.self, forKey: .walletPublicKey)
        network = try container.decode(WalletNetwork.self, forKey: .network)
        actionKind = try container.decode(CloakActionKind.self, forKey: .actionKind)
        amountLamports = try container.decodeFlexibleUInt64(forKey: .amountLamports)
        mintAddress = try container.decode(String.self, forKey: .mintAddress)
        programID = try container.decode(String.self, forKey: .programID)
        draftFingerprint = try container.decode(String.self, forKey: .draftFingerprint)
        purpose = try container.decode(String.self, forKey: .purpose)
        payloadBase64 = try container.decode(String.self, forKey: .payloadBase64)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        expiresAt = try container.decode(Date.self, forKey: .expiresAt)
    }
}

struct CloakBridgeSigningResponse: Codable, Equatable {
    let type: String
    let id: UUID
    let signedPayloadBase64: String
}

struct CloakExecutionResultFrame: Codable, Equatable {
    let type: String
    let response: CloakBridgeResponse
    let secureOutputStateBase64: String?
    let secureViewingStateBase64: String?
    let secureSpentStateBase64: String?
    let leafIndex: Int?
}

struct CloakExecutionRequest: Codable, Equatable {
    let requestID: UUID
    let command: CloakBridgeCommand
    let actionKind: CloakActionKind
    let network: WalletNetwork
    let walletPublicAddress: String
    let amountLamports: UInt64
    let mintAddress: String
    let programID: String
    let feeQuote: CloakFeeQuote?
    let approvedDraftFingerprint: String
    let recipientAddress: String?
    let rpcURL: String?
    let relayURL: String?
    let spendStateBase64: String?
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case requestID = "requestId"
        case command
        case actionKind
        case network
        case walletPublicAddress
        case amountLamports
        case mintAddress
        case programID = "programId"
        case feeQuote
        case approvedDraftFingerprint
        case recipientAddress
        case rpcURL = "rpcUrl"
        case relayURL = "relayUrl"
        case spendStateBase64
        case timestamp
    }
}

struct CloakSigningApprovalContext: Equatable {
    let requestID: UUID
    let command: CloakBridgeCommand
    let actionKind: CloakActionKind
    let walletPublicKey: String
    let network: WalletNetwork
    let amountLamports: UInt64
    let mintAddress: String
    let programID: String
    let approvedDraftFingerprint: String
    let feeAcknowledged: Bool
    let shieldReviewCompleted: Bool
    let explicitApproval: Bool
    let mainnetConfirmation: String
}

enum CloakSigningRequestValidator {
    static func validate(_ request: CloakBridgeSigningRequest, context: CloakSigningApprovalContext) throws {
        guard request.type == "sign-request" else {
            throw CloakExecutionBridgeError.signingRejected("Invalid Cloak signing frame type.")
        }
        guard request.programID == CloakConstants.programID,
              context.programID == CloakConstants.programID else {
            throw CloakExecutionBridgeError.signingRejected("Cloak signing request program id mismatch.")
        }
        guard request.walletPublicKey == context.walletPublicKey else {
            throw CloakExecutionBridgeError.signingRejected("Cloak signing request wallet mismatch.")
        }
        guard request.network == .mainnetBeta,
              context.network == .mainnetBeta else {
            throw CloakExecutionBridgeError.signingRejected("Cloak execution is mainnet-beta only.")
        }
        guard request.actionKind == context.actionKind else {
            throw CloakExecutionBridgeError.signingRejected("Cloak signing request action mismatch.")
        }
        guard request.amountLamports == context.amountLamports else {
            throw CloakExecutionBridgeError.signingRejected("Cloak signing request amount mismatch.")
        }
        guard request.mintAddress == context.mintAddress,
              request.mintAddress == CloakConstants.nativeSolMint else {
            throw CloakExecutionBridgeError.signingRejected("Cloak signing request mint mismatch.")
        }
        guard request.draftFingerprint == context.approvedDraftFingerprint,
              !request.draftFingerprint.isEmpty else {
            throw CloakExecutionBridgeError.signingRejected("Cloak signing request fingerprint mismatch.")
        }
        guard request.expiresAt > Date() else {
            throw CloakExecutionBridgeError.signingRejected("Cloak signing request expired.")
        }
        guard context.feeAcknowledged,
              context.shieldReviewCompleted,
              context.explicitApproval,
              context.mainnetConfirmation == TransactionApprovalPolicy.requiredMainnetConfirmation else {
            throw CloakExecutionBridgeError.signingRejected("Cloak approval requirements are incomplete.")
        }
        guard Data(base64Encoded: request.payloadBase64) != nil else {
            throw CloakExecutionBridgeError.signingRejected("Cloak signing payload is invalid.")
        }
        try rejectForbiddenFields(request)
    }

    private static func rejectForbiddenFields(_ request: CloakBridgeSigningRequest) throws {
        let data = try JSONEncoder().encode(request)
        try CloakBridgeContractValidator.validate(jsonData: data)
    }
}

protocol CloakInteractiveProcessRunning {
    func run(
        resolvedPath: CloakHelperResolvedPath,
        request: CloakExecutionRequest,
        context: CloakSigningApprovalContext,
        seed: Data
    ) async throws -> CloakExecutionResultFrame
}

struct CloakInteractiveProcessRunner: CloakInteractiveProcessRunning {
    func run(
        resolvedPath: CloakHelperResolvedPath,
        request: CloakExecutionRequest,
        context: CloakSigningApprovalContext,
        seed: Data
    ) async throws -> CloakExecutionResultFrame {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try runBlocking(
                        resolvedPath: resolvedPath,
                        request: request,
                        context: context,
                        seed: seed
                    )
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func runBlocking(
        resolvedPath: CloakHelperResolvedPath,
        request: CloakExecutionRequest,
        context: CloakSigningApprovalContext,
        seed: Data
    ) throws -> CloakExecutionResultFrame {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        let input = Pipe()
        process.executableURL = resolvedPath.nodeExecutable
        process.arguments = [resolvedPath.helperScript.path, request.command.rawValue]
        process.standardInput = input
        process.standardOutput = stdout
        process.standardError = stderr
        process.environment = [:]

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let initial = try encoder.encode(request)

        try process.run()
        var initialLine = initial
        initialLine.append(0x0a)
        try input.fileHandleForWriting.write(contentsOf: initialLine)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var lineBuffer = Data()

        while true {
            let chunk = stdout.fileHandleForReading.availableData
            if chunk.isEmpty {
                break
            }
            lineBuffer.append(chunk)
            while let newlineRange = lineBuffer.firstRange(of: Data([0x0a])) {
                let line = lineBuffer.subdata(in: lineBuffer.startIndex..<newlineRange.lowerBound)
                lineBuffer.removeSubrange(lineBuffer.startIndex..<newlineRange.upperBound)
                guard !line.isEmpty else {
                    continue
                }
                let object = try JSONSerialization.jsonObject(with: line) as? [String: Any]
                let type = object?["type"] as? String
                if type == "sign-request" {
                    let signingRequest = try decoder.decode(CloakBridgeSigningRequest.self, from: line)
                    let signedPayload = try sign(signingRequest, context: context, seed: seed)
                    let response = CloakBridgeSigningResponse(
                        type: "sign-response",
                        id: signingRequest.id,
                        signedPayloadBase64: signedPayload
                    )
                    var responseLine = try encoder.encode(response)
                    responseLine.append(0x0a)
                    try input.fileHandleForWriting.write(contentsOf: responseLine)
                } else if type == "result" {
                    try input.fileHandleForWriting.close()
                    process.waitUntilExit()
                    let stderrText = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    if process.terminationStatus != 0 && stderrText.isEmpty == false {
                        throw CloakExecutionBridgeError.helperRejected(CloakHelperStderrRedactor.redact(stderrText))
                    }
                    let frame = try decoder.decode(CloakExecutionResultFrame.self, from: line)
                    try validate(frame)
                    return frame
                } else {
                    throw CloakExecutionBridgeError.responseRejected("Unknown Cloak helper frame.")
                }
            }
        }

        process.waitUntilExit()
        let stderrText = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        throw CloakExecutionBridgeError.helperRejected(CloakHelperStderrRedactor.redact(stderrText))
    }

    private func sign(_ request: CloakBridgeSigningRequest, context: CloakSigningApprovalContext, seed: Data) throws -> String {
        try CloakSigningRequestValidator.validate(request, context: context)
        switch request.signingKind {
        case .signTransaction:
            return try SolanaSerializedTransaction.sign(
                base64: request.payloadBase64,
                seed: seed,
                expectedSigner: context.walletPublicKey
            )
        case .signMessage:
            guard let message = Data(base64Encoded: request.payloadBase64) else {
                throw CloakExecutionBridgeError.signingRejected("Invalid message payload.")
            }
            let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: seed)
            return try privateKey.signature(for: message).base64EncodedString()
        }
    }

    private func validate(_ frame: CloakExecutionResultFrame) throws {
        guard frame.type == "result" else {
            throw CloakExecutionBridgeError.responseRejected("final frame type mismatch")
        }
        try CloakBridgeContractValidator.validate(frame.response)
        if let state = frame.secureOutputStateBase64, Data(base64Encoded: state) == nil {
            throw CloakExecutionBridgeError.responseRejected("secure output state is invalid")
        }
        if let state = frame.secureViewingStateBase64, Data(base64Encoded: state) == nil {
            throw CloakExecutionBridgeError.responseRejected("secure viewing state is invalid")
        }
        if let state = frame.secureSpentStateBase64, Data(base64Encoded: state) == nil {
            throw CloakExecutionBridgeError.responseRejected("secure spent state is invalid")
        }
    }
}

struct CloakExecutionBridge {
    let policy: CloakBridgeExecutionPolicy
    let projectRoot: URL?
    let pathResolver: any CloakHelperPathResolving
    let processRunner: any CloakInteractiveProcessRunning

    static func liveDefault() -> CloakExecutionBridge {
        CloakExecutionBridge(
            policy: .phase25Enabled(),
            projectRoot: CloakProjectRootResolver.resolve(),
            pathResolver: CloakHelperPathResolver(),
            processRunner: CloakInteractiveProcessRunner()
        )
    }

    func execute(
        request: CloakExecutionRequest,
        context: CloakSigningApprovalContext,
        seed: Data
    ) async throws -> CloakExecutionResultFrame {
        guard policy.allowedCommands.contains(request.command) else {
            throw CloakExecutionBridgeError.commandNotAllowlisted(request.command)
        }
        guard request.network == .mainnetBeta,
              request.programID == CloakConstants.programID,
              request.mintAddress == CloakConstants.nativeSolMint else {
            throw CloakExecutionBridgeError.invalidRequest("Cloak execution request failed native validation.")
        }
        let path = try pathResolver.resolve(policy: policy, projectRoot: projectRoot)
        return try await processRunner.run(
            resolvedPath: path,
            request: request,
            context: context,
            seed: seed
        )
    }
}

enum CloakProjectRootResolver {
    static func resolve() -> URL? {
        let env = ProcessInfo.processInfo.environment
        if let explicit = env["GORKH_PROJECT_ROOT"], !explicit.isEmpty {
            return URL(fileURLWithPath: explicit)
        }
        let current = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        return firstProjectRoot(startingAt: current)
    }

    private static func firstProjectRoot(startingAt url: URL) -> URL? {
        var candidate = url.standardizedFileURL
        for _ in 0..<8 {
            let helper = candidate.appendingPathComponent(CloakHelperPathResolver.allowedRelativePath)
            if FileManager.default.fileExists(atPath: helper.path) {
                return candidate
            }
            let parent = candidate.deletingLastPathComponent()
            if parent.path == candidate.path {
                return nil
            }
            candidate = parent
        }
        return nil
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleUInt64(forKey key: Key) throws -> UInt64 {
        if let value = try? decode(UInt64.self, forKey: key) {
            return value
        }
        let stringValue = try decode(String.self, forKey: key)
        guard let value = UInt64(stringValue) else {
            throw DecodingError.dataCorruptedError(
                forKey: key,
                in: self,
                debugDescription: "Expected UInt64 or base-10 UInt64 string."
            )
        }
        return value
    }
}
