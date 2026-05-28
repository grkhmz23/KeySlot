import Foundation

enum WorkstationIDLDriftSeverity: String, Codable, Equatable {
    case info
    case warning
    case high

    var title: String { rawValue.capitalized }
}

struct WorkstationIDLDriftFinding: Codable, Equatable, Identifiable {
    let id: String
    let severity: WorkstationIDLDriftSeverity
    let source: String
    let target: String
    let category: String
    let detail: String
    let suggestedAction: String
}

struct WorkstationIDLDriftReport: Codable, Equatable {
    let sourceName: String
    let targetName: String
    let generatedAt: Date
    let findings: [WorkstationIDLDriftFinding]

    var status: WorkstationV2ReportStatus {
        if findings.contains(where: { $0.severity == .high }) {
            return .warning
        }
        if findings.contains(where: { $0.severity == .warning }) {
            return .warning
        }
        return .ready
    }

    var summary: String {
        findings.isEmpty ? "No IDL drift detected." : "\(findings.count) drift finding(s)."
    }
}

extension WorkstationIDLDriftService {
    static func compare(source: WorkstationIDL, target: WorkstationIDL, sourceLabel: String = "Loaded IDL", targetLabel: String = "Target IDL") -> WorkstationIDLDriftReport {
        var findings: [WorkstationIDLDriftFinding] = []

        if let sourceAddress = cleanProgramIDForDrift(source.address),
           let targetAddress = cleanProgramIDForDrift(target.address),
           sourceAddress != targetAddress {
            findings.append(finding(
                id: "program-id-mismatch",
                severity: .high,
                source: sourceLabel,
                target: targetLabel,
                category: "Program ID",
                detail: "\(sourceAddress) does not match \(targetAddress).",
                suggestedAction: "Confirm the intended cluster and regenerate the IDL/client from the deployed program."
            ))
        }

        compareInstructions(source.instructions, target.instructions, sourceLabel: sourceLabel, targetLabel: targetLabel, findings: &findings)
        compareAccounts(source.accounts, target.accounts, sourceLabel: sourceLabel, targetLabel: targetLabel, findings: &findings)
        compareErrors(source.errors, target.errors, sourceLabel: sourceLabel, targetLabel: targetLabel, findings: &findings)
        compareEvents(source.events, target.events, sourceLabel: sourceLabel, targetLabel: targetLabel, findings: &findings)

        return WorkstationIDLDriftReport(
            sourceName: source.name,
            targetName: target.name,
            generatedAt: Date(),
            findings: findings
        )
    }

    static func clientStalenessFindings(brain: DeveloperProjectBrain?) -> [WorkstationIDLDriftFinding] {
        guard let brain else {
            return []
        }
        return brain.clientCandidates.filter { $0.staleComparedToIDL == true }.map { client in
            finding(
                id: "stale-client-\(client.relativePath)",
                severity: .warning,
                source: "Project Brain",
                target: client.relativePath,
                category: "Client",
                detail: "Generated or frontend client appears older than the newest local IDL.",
                suggestedAction: "Regenerate client bindings from the current IDL before integration testing."
            )
        }
    }

    private static func compareInstructions(
        _ source: [WorkstationIDLInstruction],
        _ target: [WorkstationIDLInstruction],
        sourceLabel: String,
        targetLabel: String,
        findings: inout [WorkstationIDLDriftFinding]
    ) {
        let sourceByName = Dictionary(uniqueKeysWithValues: source.map { ($0.name, $0) })
        let targetByName = Dictionary(uniqueKeysWithValues: target.map { ($0.name, $0) })
        for name in sourceByName.keys.sorted() where targetByName[name] == nil {
            findings.append(finding(id: "instruction-removed-\(name)", severity: .high, source: sourceLabel, target: targetLabel, category: "Instruction", detail: "\(name) exists only in source.", suggestedAction: "Check whether the generated/deployed IDL is stale."))
        }
        for name in targetByName.keys.sorted() where sourceByName[name] == nil {
            findings.append(finding(id: "instruction-added-\(name)", severity: .warning, source: sourceLabel, target: targetLabel, category: "Instruction", detail: "\(name) exists only in target.", suggestedAction: "Refresh local project analysis and generated clients."))
        }
        for name in sourceByName.keys.sorted() {
            guard let left = sourceByName[name], let right = targetByName[name] else {
                continue
            }
            let leftArgs = left.args.map { "\($0.name):\($0.type)" }
            let rightArgs = right.args.map { "\($0.name):\($0.type)" }
            if leftArgs != rightArgs {
                findings.append(finding(id: "instruction-args-\(name)", severity: .high, source: sourceLabel, target: targetLabel, category: "Instruction args", detail: "\(name) args changed from \(leftArgs.joined(separator: ", ")) to \(rightArgs.joined(separator: ", ")).", suggestedAction: "Regenerate clients and update transaction builders before using this instruction."))
            }
            let leftAccounts = left.accounts.map { "\($0.name):signer=\($0.isSigner):writable=\($0.isMut)" }
            let rightAccounts = right.accounts.map { "\($0.name):signer=\($0.isSigner):writable=\($0.isMut)" }
            if leftAccounts != rightAccounts {
                findings.append(finding(id: "instruction-accounts-\(name)", severity: .high, source: sourceLabel, target: targetLabel, category: "Instruction accounts", detail: "\(name) account list/signature/writable metadata changed.", suggestedAction: "Review account ordering and signer/writable constraints before sending transactions."))
            }
        }
    }

    private static func compareAccounts(
        _ source: [WorkstationIDLAccount],
        _ target: [WorkstationIDLAccount],
        sourceLabel: String,
        targetLabel: String,
        findings: inout [WorkstationIDLDriftFinding]
    ) {
        let sourceByName = Dictionary(uniqueKeysWithValues: source.map { ($0.name, $0) })
        let targetByName = Dictionary(uniqueKeysWithValues: target.map { ($0.name, $0) })
        for name in sourceByName.keys.sorted() where targetByName[name] == nil {
            findings.append(finding(id: "account-removed-\(name)", severity: .warning, source: sourceLabel, target: targetLabel, category: "Account", detail: "\(name) exists only in source.", suggestedAction: "Check whether account decoding uses the correct IDL."))
        }
        for name in targetByName.keys.sorted() where sourceByName[name] == nil {
            findings.append(finding(id: "account-added-\(name)", severity: .warning, source: sourceLabel, target: targetLabel, category: "Account", detail: "\(name) exists only in target.", suggestedAction: "Refresh Account Decoder source selection."))
        }
        for name in sourceByName.keys.sorted() {
            guard let left = sourceByName[name], let right = targetByName[name] else {
                continue
            }
            if left.discriminatorHex != right.discriminatorHex {
                findings.append(finding(id: "account-discriminator-\(name)", severity: .high, source: sourceLabel, target: targetLabel, category: "Discriminator", detail: "\(name) discriminator changed.", suggestedAction: "Do not decode account data with a stale IDL."))
            }
            let leftFields = left.fields.map { "\($0.name):\($0.type)" }
            let rightFields = right.fields.map { "\($0.name):\($0.type)" }
            if leftFields != rightFields {
                findings.append(finding(id: "account-fields-\(name)", severity: .high, source: sourceLabel, target: targetLabel, category: "Account fields", detail: "\(name) fields changed from \(leftFields.joined(separator: ", ")) to \(rightFields.joined(separator: ", ")).", suggestedAction: "Use the newest matching IDL before decoding accounts or generating fixtures."))
            }
        }
    }

    private static func compareErrors(
        _ source: [WorkstationIDLError],
        _ target: [WorkstationIDLError],
        sourceLabel: String,
        targetLabel: String,
        findings: inout [WorkstationIDLDriftFinding]
    ) {
        let sourceByCode = Dictionary(uniqueKeysWithValues: source.map { ($0.code, $0) })
        let targetByCode = Dictionary(uniqueKeysWithValues: target.map { ($0.code, $0) })
        for code in Set(sourceByCode.keys).union(targetByCode.keys).sorted() {
            guard let left = sourceByCode[code], let right = targetByCode[code] else {
                findings.append(finding(id: "error-code-\(code)", severity: .warning, source: sourceLabel, target: targetLabel, category: "Error", detail: "Error code \(code) exists on only one side.", suggestedAction: "Review error mappings used by Transaction Debugger."))
                continue
            }
            if left.name != right.name || left.message != right.message {
                findings.append(finding(id: "error-code-changed-\(code)", severity: .warning, source: sourceLabel, target: targetLabel, category: "Error", detail: "Error code \(code) changed from \(left.name) to \(right.name).", suggestedAction: "Refresh error mappings before debugging failed transactions."))
            }
        }
    }

    private static func compareEvents(
        _ source: [WorkstationIDLNamedType],
        _ target: [WorkstationIDLNamedType],
        sourceLabel: String,
        targetLabel: String,
        findings: inout [WorkstationIDLDriftFinding]
    ) {
        let sourceNames = Set(source.map(\.name))
        let targetNames = Set(target.map(\.name))
        for name in sourceNames.symmetricDifference(targetNames).sorted() {
            findings.append(finding(id: "event-\(name)", severity: .info, source: sourceLabel, target: targetLabel, category: "Event", detail: "\(name) event exists on only one side.", suggestedAction: "Refresh event consumers if this event is user-facing."))
        }
    }

    private static func finding(
        id: String,
        severity: WorkstationIDLDriftSeverity,
        source: String,
        target: String,
        category: String,
        detail: String,
        suggestedAction: String
    ) -> WorkstationIDLDriftFinding {
        WorkstationIDLDriftFinding(
            id: id,
            severity: severity,
            source: AgentSafetyRedactor.redact(source),
            target: AgentSafetyRedactor.redact(target),
            category: category,
            detail: AgentSafetyRedactor.redact(detail),
            suggestedAction: AgentSafetyRedactor.redact(suggestedAction)
        )
    }

    private static func cleanProgramIDForDrift(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              SolanaAddressValidator.isValidAddress(value) else {
            return nil
        }
        return value
    }
}
