import Foundation

struct TransactionLogAnalysis: Equatable {
    let summary: TransactionLogSummary
    let anchorError: TransactionAnchorError?
    let customProgramError: TransactionCustomProgramError?
    let idlErrorMatch: TransactionIDLErrorMatch?
    let computeTimeline: [TransactionComputeEvent]
    let computeUnits: UInt64?
    let likelyRootCause: String
    let suggestedNextSteps: [String]
}

enum TransactionLogParser {
    static func parse(logs: [String], idlErrors: [WorkstationIDLError]) -> TransactionLogAnalysis {
        let bounded = logs.prefix(240).map { safeLine(String($0.prefix(900))) }
        var anchorErrorCode: String?
        var anchorErrorNumber: Int?
        var anchorErrorMessage: String?
        var anchorSourceLine: String?
        var customError: TransactionCustomProgramError?
        var failedProgramID: String?
        var failedProgramLine: String?
        var computeEvents: [TransactionComputeEvent] = []

        for line in bounded {
            if line.localizedCaseInsensitiveContains("AnchorError occurred") {
                anchorSourceLine = line
            }
            if let code = capture(in: line, pattern: #"Error Code:\s*([A-Za-z0-9_]+)"#) {
                anchorErrorCode = code
                anchorSourceLine = anchorSourceLine ?? line
            }
            if let number = capture(in: line, pattern: #"Error Number:\s*([0-9]+)"#).flatMap(Int.init) {
                anchorErrorNumber = number
                anchorSourceLine = anchorSourceLine ?? line
            }
            if let message = capture(in: line, pattern: #"Error Message:\s*(.+)"#) {
                anchorErrorMessage = message
                anchorSourceLine = anchorSourceLine ?? line
            }
            if let failedProgram = capture(in: line, pattern: #"Program\s+([1-9A-HJ-NP-Za-km-z]+)\s+failed:"#) {
                failedProgramID = failedProgram
                failedProgramLine = line
            }
            if let hex = capture(in: line, pattern: #"custom program error:\s*0x([0-9a-fA-F]+)"#),
               let decimal = Int(hex, radix: 16) {
                customError = TransactionCustomProgramError(
                    programID: failedProgramID,
                    hexCode: "0x\(hex.lowercased())",
                    decimalCode: decimal,
                    sourceLine: line
                )
            }
            if let event = parseComputeEvent(from: line) {
                computeEvents.append(event)
            }
        }

        let anchorError: TransactionAnchorError?
        if anchorErrorCode != nil || anchorErrorNumber != nil || anchorErrorMessage != nil || anchorSourceLine != nil {
            anchorError = TransactionAnchorError(
                errorCode: anchorErrorCode,
                errorNumber: anchorErrorNumber,
                errorMessage: anchorErrorMessage,
                sourceLine: anchorSourceLine
            )
        } else {
            anchorError = nil
        }

        let idlCode = anchorErrorNumber ?? customError?.decimalCode
        let idlErrorMatch = idlCode.flatMap { code in
            idlErrors.first(where: { $0.code == code }).map {
                TransactionIDLErrorMatch(code: $0.code, name: $0.name, message: $0.message, source: "Loaded Anchor IDL")
            }
        }

        let errorLineCount = bounded.filter { line in
            line.localizedCaseInsensitiveContains("error")
                || line.localizedCaseInsensitiveContains("failed")
        }.count
        let computeLineCount = computeEvents.count
        let computeUnits = computeEvents.last?.consumed

        let likelyRootCause: String
        if let match = idlErrorMatch {
            likelyRootCause = "Transaction failed with IDL error \(match.name) (\(match.code))."
        } else if let anchorError {
            if let code = anchorError.errorCode {
                likelyRootCause = "Transaction failed with Anchor error \(code)."
            } else {
                likelyRootCause = "Transaction failed with an Anchor error that could not be fully mapped."
            }
        } else if let customError {
            likelyRootCause = "Transaction failed with unmapped custom program error \(customError.hexCode) (\(customError.decimalCode))."
        } else if let failedProgramID {
            likelyRootCause = "Program \(TransactionInstructionLabeler.label(for: failedProgramID)) reported a failure."
        } else if errorLineCount > 0 {
            likelyRootCause = "Logs contain error lines, but no Anchor or custom program error was mapped."
        } else {
            likelyRootCause = "No failure was detected in logs."
        }

        var nextSteps: [String] = []
        if idlErrorMatch == nil, customError != nil {
            nextSteps.append("Load the matching Anchor IDL to map the custom error code.")
        }
        if failedProgramID != nil {
            nextSteps.append("Review the failed program's instruction accounts, signer flags, and writable flags.")
        }
        if computeEvents.contains(where: { event in
            guard let limit = event.limit, limit > 0 else { return false }
            return Double(event.consumed) / Double(limit) > 0.90
        }) {
            nextSteps.append("Compute usage is close to the limit; review compute budget instructions and expensive CPI paths.")
        }
        if nextSteps.isEmpty {
            nextSteps.append("Review the instruction tree, logs, and account table before making code or account changes.")
        }

        return TransactionLogAnalysis(
            summary: TransactionLogSummary(
                totalLines: bounded.count,
                errorLineCount: errorLineCount,
                computeLineCount: computeLineCount,
                failedProgramID: failedProgramID,
                failedProgramLine: failedProgramLine
            ),
            anchorError: anchorError,
            customProgramError: customError,
            idlErrorMatch: idlErrorMatch,
            computeTimeline: computeEvents,
            computeUnits: computeUnits,
            likelyRootCause: likelyRootCause,
            suggestedNextSteps: nextSteps
        )
    }

    private static func parseComputeEvent(from line: String) -> TransactionComputeEvent? {
        guard let regex = try? NSRegularExpression(
            pattern: #"Program\s+([1-9A-HJ-NP-Za-km-z]+)\s+consumed\s+([0-9]+)\s+of\s+([0-9]+)\s+compute units"#
        ) else {
            return nil
        }
        let range = NSRange(line.startIndex..., in: line)
        guard let match = regex.firstMatch(in: line, range: range),
              match.numberOfRanges >= 4,
              let programRange = Range(match.range(at: 1), in: line),
              let consumedRange = Range(match.range(at: 2), in: line),
              let limitRange = Range(match.range(at: 3), in: line),
              let consumed = UInt64(String(line[consumedRange])),
              let limit = UInt64(String(line[limitRange])) else {
            return nil
        }
        let programID = String(line[programRange])
        return TransactionComputeEvent(
            programID: programID,
            programName: TransactionInstructionLabeler.label(for: programID),
            consumed: consumed,
            limit: limit,
            line: line
        )
    }

    private static func capture(in line: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let range = NSRange(line.startIndex..., in: line)
        guard let match = regex.firstMatch(in: line, range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: line) else {
            return nil
        }
        return String(line[captureRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func safeLine(_ line: String) -> String {
        [
            "privateKey",
            "private key",
            "secretKey",
            "secret key",
            "seed phrase",
            "mnemonic",
            "wallet JSON",
            "signingSeed",
            "signing seed",
            "RPC secret",
            "api key"
        ].reduce(AgentSafetyRedactor.redact(line)) { text, term in
            text.replacingOccurrences(of: term, with: "[redacted]", options: [.caseInsensitive])
        }
    }
}

enum TransactionInstructionTreeBuilder {
    static func build(
        decoded: DecodedTransaction,
        innerInstructionsRaw: [[String: Any]],
        logAnalysis: TransactionLogAnalysis
    ) -> (topLevel: [InstructionDebugNode], inner: [InstructionDebugNode]) {
        let innerByIndex = parseInnerInstructions(innerInstructionsRaw, decoded: decoded, logAnalysis: logAnalysis)
        let topLevel = decoded.instructions.map { instruction in
            makeNode(
                id: "top:\(instruction.index):\(instruction.programID)",
                index: instruction.index,
                programID: instruction.programID,
                instructionName: instruction.decodedAction,
                accounts: instruction.accounts,
                innerInstructions: innerByIndex[instruction.index] ?? [],
                logAnalysis: logAnalysis
            )
        }
        return (topLevel, innerByIndex.keys.sorted().flatMap { innerByIndex[$0] ?? [] })
    }

    private static func parseInnerInstructions(
        _ groups: [[String: Any]],
        decoded: DecodedTransaction,
        logAnalysis: TransactionLogAnalysis
    ) -> [Int: [InstructionDebugNode]] {
        var result: [Int: [InstructionDebugNode]] = [:]
        for group in groups {
            let parentIndex = intValue(group["index"]) ?? 0
            let instructions = group["instructions"] as? [[String: Any]] ?? []
            result[parentIndex] = instructions.enumerated().map { offset, raw in
                let programIndex = intValue(raw["programIdIndex"]) ?? -1
                let programID = decoded.accountMetas.first(where: { $0.index == programIndex })?.address ?? "Unknown Program"
                let accounts = (raw["accounts"] as? [Any] ?? []).compactMap { intValue($0) }
                    .compactMap { accountIndex in decoded.accountMetas.first(where: { $0.index == accountIndex }) }
                let dataLength = (raw["data"] as? String)?.count ?? 0
                return makeNode(
                    id: "inner:\(parentIndex):\(offset):\(programID)",
                    index: offset,
                    programID: programID,
                    instructionName: dataLength > 0 ? "Inner instruction data (\(dataLength) chars)" : "Inner instruction",
                    accounts: accounts,
                    innerInstructions: [],
                    logAnalysis: logAnalysis
                )
            }
        }
        return result
    }

    private static func makeNode(
        id: String,
        index: Int,
        programID: String,
        instructionName: String,
        accounts: [DecodedAccountMeta],
        innerInstructions: [InstructionDebugNode],
        logAnalysis: TransactionLogAnalysis
    ) -> InstructionDebugNode {
        let logs = logsForProgram(programID, analysis: logAnalysis)
        let computeUnits = logAnalysis.computeTimeline.last(where: { $0.programID == programID })?.consumed
        let signerWritableHints = accounts.map { account in
            let flags = [
                account.isSigner ? "signer" : nil,
                account.isWritable ? "writable" : "readonly"
            ].compactMap { $0 }.joined(separator: ", ")
            return "#\(account.index) \(short(account.address)) \(flags)"
        }
        return InstructionDebugNode(
            id: id,
            index: index,
            programID: programID,
            programName: TransactionInstructionLabeler.label(for: programID),
            instructionName: instructionName,
            accounts: accounts.map(\.address),
            signerWritableHints: signerWritableHints,
            innerInstructions: innerInstructions,
            logs: logs,
            computeUnitsConsumed: computeUnits,
            errorAtThisInstruction: logAnalysis.summary.failedProgramID == programID
        )
    }

    private static func logsForProgram(_ programID: String, analysis: TransactionLogAnalysis) -> [String] {
        let failed = analysis.summary.failedProgramID == programID ? analysis.summary.failedProgramLine : nil
        let compute = analysis.computeTimeline.filter { $0.programID == programID }.map(\.line)
        return Array(([failed].compactMap { $0 } + compute).prefix(12))
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let int = value as? Int {
            return int
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        return nil
    }

    private static func short(_ value: String) -> String {
        guard value.count > 12 else {
            return value
        }
        return "\(value.prefix(4))...\(value.suffix(4))"
    }
}

enum TransactionAccountMapper {
    static func map(
        decoded: DecodedTransaction,
        idl: WorkstationIDL?,
        projectBrain: DeveloperProjectBrain?
    ) -> (accounts: [TransactionDebugAccountEntry], pdaFindings: [TransactionPDAMismatchCandidate]) {
        var idlNames: [String: String] = [:]
        var pdaFindings: [TransactionPDAMismatchCandidate] = []

        if let idl {
            for instruction in decoded.instructions {
                guard idl.address == nil || idl.address == instruction.programID else {
                    continue
                }
                let candidates = idl.instructions.filter { $0.accounts.count == instruction.accounts.count }
                guard let idlInstruction = candidates.count == 1 ? candidates.first : nil else {
                    if !candidates.isEmpty {
                        pdaFindings.append(TransactionPDAMismatchCandidate(
                            severity: .info,
                            instructionName: nil,
                            accountName: nil,
                            expectedAddress: nil,
                            actualAddress: nil,
                            reason: "Multiple IDL instructions match account count for program \(TransactionInstructionLabeler.label(for: instruction.programID)); account-name mapping is ambiguous.",
                            deterministic: false
                        ))
                    }
                    continue
                }
                for (index, account) in instruction.accounts.enumerated() where index < idlInstruction.accounts.count {
                    let idlAccount = idlInstruction.accounts[index]
                    idlNames[account.address] = idlAccount.name
                    if idlAccount.isSigner, !account.isSigner {
                        pdaFindings.append(TransactionPDAMismatchCandidate(
                            severity: .high,
                            instructionName: idlInstruction.name,
                            accountName: idlAccount.name,
                            expectedAddress: nil,
                            actualAddress: account.address,
                            reason: "IDL expects this account to sign, but the transaction marks it non-signer.",
                            deterministic: true
                        ))
                    }
                    if idlAccount.isMut, !account.isWritable {
                        pdaFindings.append(TransactionPDAMismatchCandidate(
                            severity: .warning,
                            instructionName: idlInstruction.name,
                            accountName: idlAccount.name,
                            expectedAddress: nil,
                            actualAddress: account.address,
                            reason: "IDL expects this account writable, but the transaction marks it readonly.",
                            deterministic: true
                        ))
                    }
                    if let pda = idlAccount.pda {
                        pdaFindings.append(contentsOf: comparePDA(
                            pda: pda,
                            instructionProgramID: instruction.programID,
                            instructionName: idlInstruction.name,
                            accountName: idlAccount.name,
                            actualAddress: account.address
                        ))
                    }
                }
                if instruction.accounts.count != idlInstruction.accounts.count {
                    pdaFindings.append(TransactionPDAMismatchCandidate(
                        severity: .warning,
                        instructionName: idlInstruction.name,
                        accountName: nil,
                        expectedAddress: nil,
                        actualAddress: nil,
                        reason: "IDL account count is \(idlInstruction.accounts.count), but transaction instruction has \(instruction.accounts.count).",
                        deterministic: true
                    ))
                }
            }
        }

        let brainPDAFindings = (projectBrain?.pdaCandidates ?? []).compactMap { candidate -> TransactionPDAMismatchCandidate? in
            guard let reason = candidate.unsupportedReason, candidate.confidence == .low else {
                return nil
            }
            return TransactionPDAMismatchCandidate(
                severity: .info,
                instructionName: candidate.instructionName,
                accountName: candidate.label,
                expectedAddress: nil,
                actualAddress: nil,
                reason: "Project Brain PDA hint is not deterministic for transaction matching: \(reason)",
                deterministic: false
            )
        }

        let accounts = decoded.accountMetas.map {
            TransactionDebugAccountEntry(
                index: $0.index,
                pubkey: $0.address,
                isSigner: $0.isSigner,
                isWritable: $0.isWritable,
                idlAccountName: idlNames[$0.address]
            )
        }
        return (accounts, pdaFindings + brainPDAFindings)
    }

    private static func comparePDA(
        pda: WorkstationIDLPDA,
        instructionProgramID: String,
        instructionName: String,
        accountName: String,
        actualAddress: String
    ) -> [TransactionPDAMismatchCandidate] {
        let programID = pda.program.flatMap { SolanaAddressValidator.isValidAddress($0) ? $0 : nil } ?? instructionProgramID
        guard SolanaAddressValidator.isValidAddress(programID) else {
            return [
                TransactionPDAMismatchCandidate(
                    severity: .info,
                    instructionName: instructionName,
                    accountName: accountName,
                    expectedAddress: nil,
                    actualAddress: actualAddress,
                    reason: "PDA metadata exists, but a concrete program id was not available.",
                    deterministic: false
                )
            ]
        }
        var seedData: [Data] = []
        for seed in pda.seeds {
            guard seed.kind == "const" else {
                return [
                    TransactionPDAMismatchCandidate(
                        severity: .info,
                        instructionName: instructionName,
                        accountName: accountName,
                        expectedAddress: nil,
                        actualAddress: actualAddress,
                        reason: "PDA uses dynamic or non-displayable seeds, so the debugger cannot derive it safely.",
                        deterministic: false
                    )
                ]
            }
            if let constBytes = seed.constBytes {
                seedData.append(Data(constBytes))
            } else if let summary = seed.valueSummary,
                      summary.range(of: #"^[0-9]+\s+bytes$"#, options: .regularExpression) == nil,
                      summary != "unparsed const seed" {
                seedData.append(Data(summary.utf8))
            } else {
                return [
                    TransactionPDAMismatchCandidate(
                        severity: .info,
                        instructionName: instructionName,
                        accountName: accountName,
                        expectedAddress: nil,
                        actualAddress: actualAddress,
                        reason: "PDA uses dynamic or non-displayable seeds, so the debugger cannot derive it safely.",
                        deterministic: false
                    )
                ]
            }
        }
        do {
            let derived = try ProgramDerivedAddress.findProgramAddress(seeds: seedData, programID: programID).base58Address
            guard derived != actualAddress else {
                return []
            }
            return [
                TransactionPDAMismatchCandidate(
                    severity: .high,
                    instructionName: instructionName,
                    accountName: accountName,
                    expectedAddress: derived,
                    actualAddress: actualAddress,
                    reason: "IDL PDA metadata with concrete const seeds derives a different address than the transaction supplied.",
                    deterministic: true
                )
            ]
        } catch {
            return [
                TransactionPDAMismatchCandidate(
                    severity: .info,
                    instructionName: instructionName,
                    accountName: accountName,
                    expectedAddress: nil,
                    actualAddress: actualAddress,
                    reason: "PDA derivation failed: \(error.localizedDescription)",
                    deterministic: false
                )
            ]
        }
    }
}

struct TransactionDebugService {
    private let rpcClient: TransactionDebugRPCClient

    init(
        session: URLSession = .shared,
        configuration: RPCFastConfiguration = RPCFastConfiguration()
    ) {
        rpcClient = TransactionDebugRPCClient(session: session, configuration: configuration)
    }

    func debugTransaction(
        signature: String,
        cluster: WorkstationCluster,
        projectId: String? = nil,
        idlId: String? = nil,
        projectBrain: DeveloperProjectBrain? = nil,
        idl: WorkstationIDL? = nil
    ) async throws -> TransactionDebugReport {
        let trimmed = signature.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let decodedSignature = Base58.decode(trimmed), decodedSignature.count == 64 else {
            return .unsupported(signature: trimmed, cluster: cluster, reason: "Input must be a 64-byte base58 Solana transaction signature.")
        }

        guard let fetched = try await rpcClient.getTransaction(signature: trimmed, cluster: cluster) else {
            return .notFound(signature: trimmed, cluster: cluster)
        }

        let decoded: DecodedTransaction
        do {
            decoded = try TransactionDecoder.decodeFetchedTransaction(
                transactionBase64: fetched.transactionBase64,
                signature: trimmed,
                slot: fetched.slot,
                blockTime: fetched.blockTime,
                loadedWritableAddresses: fetched.loadedWritableAddresses,
                loadedReadonlyAddresses: fetched.loadedReadonlyAddresses,
                network: cluster.walletNetwork ?? .devnet
            )
        } catch {
            return .unsupported(
                signature: trimmed,
                cluster: cluster,
                reason: "Fetched transaction could not be decoded: \(error.localizedDescription)"
            )
        }

        let logAnalysis = TransactionLogParser.parse(logs: fetched.logs, idlErrors: idl?.errors ?? [])
        let tree = TransactionInstructionTreeBuilder.build(
            decoded: decoded,
            innerInstructionsRaw: fetched.innerInstructions,
            logAnalysis: logAnalysis
        )
        let mapped = TransactionAccountMapper.map(decoded: decoded, idl: idl, projectBrain: projectBrain)
        let status: TransactionDebugStatus = fetched.err == nil ? .success : .failed
        let programIds = decoded.programSummaries.map(\.programID)
        let nextSteps = suggestedNextSteps(
            status: status,
            idl: idl,
            pdaFindings: mapped.pdaFindings,
            logAnalysis: logAnalysis
        )
        return TransactionDebugReport(
            signature: trimmed,
            cluster: cluster,
            status: status,
            slot: fetched.slot,
            blockTime: fetched.blockTime,
            fee: fetched.fee,
            err: fetched.err,
            programIds: programIds,
            topLevelInstructions: tree.topLevel,
            innerInstructions: tree.inner,
            logs: fetched.logs,
            logSummary: logAnalysis.summary,
            anchorError: logAnalysis.anchorError,
            customProgramError: logAnalysis.customProgramError,
            idlErrorMatch: logAnalysis.idlErrorMatch,
            computeUnits: logAnalysis.computeUnits,
            computeTimeline: logAnalysis.computeTimeline,
            accountTable: mapped.accounts,
            pdaMismatchCandidates: mapped.pdaFindings,
            likelyRootCause: status == .success ? "Transaction succeeded. Review logs and account writes for expected behavior." : logAnalysis.likelyRootCause,
            suggestedNextSteps: nextSteps,
            replaySupportStatus: "Read-only replay is limited to fetched transaction data, logs, and IDL/project metadata. This page cannot sign, broadcast, or mutate state."
        )
    }

    func fetchAccountDetails(for report: TransactionDebugReport, limit: Int = 20) async throws -> TransactionDebugReport {
        let bounded = Array(report.accountTable.prefix(max(0, min(limit, 20))))
        let details = try await rpcClient.getAccountDetails(addresses: bounded.map(\.pubkey), cluster: report.cluster)
        let detailByAddress = Dictionary(uniqueKeysWithValues: details.map { ($0.address, $0) })
        let updated = report.accountTable.map { entry in
            guard let detail = detailByAddress[entry.pubkey] else {
                return entry
            }
            return entry.withDetail(detail)
        }
        return report.replacingAccountTable(updated)
    }

    private func suggestedNextSteps(
        status: TransactionDebugStatus,
        idl: WorkstationIDL?,
        pdaFindings: [TransactionPDAMismatchCandidate],
        logAnalysis: TransactionLogAnalysis
    ) -> [String] {
        var steps = logAnalysis.suggestedNextSteps
        if idl == nil {
            steps.append("Load the matching Anchor IDL for account-name and error-code mapping.")
        }
        if pdaFindings.contains(where: { $0.deterministic && $0.severity == .high }) {
            steps.append("Review deterministic PDA mismatches before retrying the transaction.")
        }
        if status == .success {
            steps = ["Use the instruction tree and account table to confirm the transaction matched your intended action."]
        }
        var seen = Set<String>()
        return steps.filter { seen.insert($0).inserted }.prefix(6).map { $0 }
    }
}

private struct TransactionDebugFetchedTransaction {
    let transactionBase64: String
    let slot: UInt64?
    let blockTime: Date?
    let fee: UInt64?
    let err: String?
    let logs: [String]
    let innerInstructions: [[String: Any]]
    let loadedWritableAddresses: [String]
    let loadedReadonlyAddresses: [String]
}

private struct TransactionDebugRPCClient {
    private let session: URLSession
    private let configuration: RPCFastConfiguration

    init(session: URLSession, configuration: RPCFastConfiguration) {
        self.session = session
        self.configuration = configuration
    }

    func getTransaction(signature: String, cluster: WorkstationCluster) async throws -> TransactionDebugFetchedTransaction? {
        let result = try await request(
            method: "getTransaction",
            params: [
                signature,
                [
                    "encoding": "base64",
                    "commitment": "confirmed",
                    "maxSupportedTransactionVersion": 0
                ]
            ],
            cluster: cluster
        )
        if result is NSNull {
            return nil
        }
        guard let dictionary = result as? [String: Any] else {
            throw SolanaRPCError.invalidResponse
        }
        guard let transaction = dictionary["transaction"] else {
            throw SolanaRPCError.invalidResponse
        }
        let transactionBase64: String?
        if let array = transaction as? [Any] {
            transactionBase64 = array.first as? String
        } else if let object = transaction as? [String: Any],
                  let message = object["message"] as? String {
            transactionBase64 = message
        } else {
            transactionBase64 = nil
        }
        guard let transactionBase64 else {
            throw SolanaRPCError.invalidResponse
        }
        let meta = dictionary["meta"] as? [String: Any]
        return TransactionDebugFetchedTransaction(
            transactionBase64: transactionBase64,
            slot: uint64Value(dictionary["slot"]),
            blockTime: uint64Value(dictionary["blockTime"]).map { Date(timeIntervalSince1970: TimeInterval($0)) },
            fee: uint64Value(meta?["fee"]),
            err: stringIfPresent(meta?["err"]),
            logs: (meta?["logMessages"] as? [String]) ?? [],
            innerInstructions: (meta?["innerInstructions"] as? [[String: Any]]) ?? [],
            loadedWritableAddresses: loadedAddresses(meta)["writable"] ?? [],
            loadedReadonlyAddresses: loadedAddresses(meta)["readonly"] ?? []
        )
    }

    func getAccountDetails(addresses: [String], cluster: WorkstationCluster) async throws -> [TransactionDebugAccountDetail] {
        var details: [TransactionDebugAccountDetail] = []
        for address in addresses where SolanaAddressValidator.isValidAddress(address) {
            let result = try await request(
                method: "getAccountInfo",
                params: [
                    address,
                    [
                        "encoding": "jsonParsed",
                        "commitment": "confirmed"
                    ]
                ],
                cluster: cluster
            )
            guard let dictionary = result as? [String: Any] else {
                continue
            }
            guard !(dictionary["value"] is NSNull),
                  let value = dictionary["value"] as? [String: Any] else {
                continue
            }
            details.append(parseAccountDetail(address: address, value: value))
        }
        return details
    }

    private func request(method: String, params: [Any], cluster: WorkstationCluster) async throws -> Any {
        guard ["getTransaction", "getAccountInfo", "getSignatureStatuses"].contains(method) else {
            throw SolanaRPCError.methodBlocked("Transaction Debugger allows read-only transaction/account/status RPC methods only.")
        }
        var request = URLRequest(url: cluster.rpcURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let network = cluster.walletNetwork {
            configuration.applyAuthentication(to: &request, network: network)
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "jsonrpc": "2.0",
            "id": UUID().uuidString,
            "method": method,
            "params": params
        ])

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw SolanaRPCError.timeout("RPC endpoint timed out.")
        } catch {
            throw SolanaRPCError.transport(configuration.redact(error.localizedDescription))
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SolanaRPCError.transport("Solana RPC did not return an HTTP response.")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "No response body."
            throw SolanaRPCError.transport(configuration.redact("HTTP \(httpResponse.statusCode): \(body.prefix(500))"))
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SolanaRPCError.invalidResponse
        }
        if let error = json["error"] as? [String: Any] {
            let message = error["message"] as? String ?? "Solana RPC error"
            throw SolanaRPCError.rpc(configuration.redact(message))
        }
        guard let result = json["result"] else {
            throw SolanaRPCError.invalidResponse
        }
        return result
    }

    private func parseAccountDetail(address: String, value: [String: Any]) -> TransactionDebugAccountDetail {
        let owner = value["owner"] as? String
        let lamports = uint64Value(value["lamports"])
        let executable = value["executable"] as? Bool
        let dataLength = intValue(value["space"])
        var tokenMint: String?
        var tokenOwner: String?
        var tokenAmountRaw: String?
        if let data = value["data"] as? [String: Any],
           let parsed = data["parsed"] as? [String: Any],
           let type = parsed["type"] as? String,
           let info = parsed["info"] as? [String: Any],
           type == "account" {
            tokenMint = info["mint"] as? String
            tokenOwner = info["owner"] as? String
            tokenAmountRaw = (info["tokenAmount"] as? [String: Any])?["amount"] as? String
        }
        return TransactionDebugAccountDetail(
            address: address,
            ownerProgram: owner,
            ownerLabel: owner.map(TransactionInstructionLabeler.label(for:)),
            lamports: lamports,
            executable: executable,
            dataLength: dataLength,
            tokenMint: tokenMint,
            tokenOwner: tokenOwner,
            tokenAmountRaw: tokenAmountRaw,
            fetchedAt: Date()
        )
    }

    private func loadedAddresses(_ meta: [String: Any]?) -> [String: [String]] {
        guard let loaded = meta?["loadedAddresses"] as? [String: Any] else {
            return [:]
        }
        return [
            "writable": loaded["writable"] as? [String] ?? [],
            "readonly": loaded["readonly"] as? [String] ?? []
        ]
    }

    private func stringIfPresent(_ value: Any?) -> String? {
        guard let value, !(value is NSNull) else {
            return nil
        }
        return AgentSafetyRedactor.redact(String(describing: value))
    }

    private func uint64Value(_ value: Any?) -> UInt64? {
        if let number = value as? NSNumber {
            return number.uint64Value
        }
        if let int = value as? Int {
            return UInt64(int)
        }
        if let uint = value as? UInt64 {
            return uint
        }
        return nil
    }

    private func intValue(_ value: Any?) -> Int? {
        if let number = value as? NSNumber {
            return number.intValue
        }
        if let int = value as? Int {
            return int
        }
        return nil
    }
}
