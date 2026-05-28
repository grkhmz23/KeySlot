import Foundation

enum DeveloperProjectBrainService {
    static func analyze(
        project: WorkstationProject?,
        idl: WorkstationIDL?,
        evidence: [WorkstationProgramOperationEvidence],
        toolchain: WorkstationToolchainSnapshot,
        cluster: WorkstationCluster
    ) -> WorkstationV2Report {
        guard let project else {
            return WorkstationV2Report(
                capability: .projectBrain,
                status: .unavailable,
                summary: "No project is imported. Project Brain only reports on real imported metadata.",
                nextActions: ["Import a folder, zip, or HTTPS Git project metadata first."]
            )
        }

        var findings: [WorkstationV2Finding] = [
            WorkstationV2Finding(
                id: "framework",
                severity: .info,
                title: "Detected framework",
                detail: project.detectedFramework.rawValue,
                evidence: detectedFileSummary(project.detectedFiles)
            )
        ]

        if project.trustStatus != .trusted {
            findings.append(WorkstationV2Finding(
                id: "trust",
                severity: .medium,
                title: "Project is untrusted",
                detail: "Browsing and IDL review are allowed, but build/deploy/test command previews remain locked until the exact trust phrase is accepted."
            ))
        }

        if let idl {
            findings.append(WorkstationV2Finding(
                id: "idl",
                severity: .info,
                title: "Parsed IDL loaded",
                detail: idl.summary,
                evidence: idl.name
            ))
        } else if project.detectedFiles.idlJSONCount + project.detectedFiles.targetIDLJSONCount > 0 {
            findings.append(WorkstationV2Finding(
                id: "idl-not-loaded",
                severity: .low,
                title: "IDL files detected but not loaded",
                detail: "Open IDL Browser and parse a real Anchor IDL JSON file before PDA, drift, or frontend analysis."
            ))
        }

        if toolchain.isAvailable(.anchor), toolchain.isAvailable(.solana) {
            findings.append(WorkstationV2Finding(
                id: "toolchain-ready",
                severity: .info,
                title: "Anchor/Solana toolchain active",
                detail: "Program Manager can prepare localnet/devnet command previews after trust and wallet checks."
            ))
        } else {
            findings.append(WorkstationV2Finding(
                id: "toolchain-missing",
                severity: .medium,
                title: "Program toolchain incomplete",
                detail: "Anchor CLI and Solana CLI must both be active before localnet/devnet program operations can proceed."
            ))
        }

        if cluster == .mainnetBeta {
            findings.append(WorkstationV2Finding(
                id: "mainnet-lock",
                severity: .high,
                title: "Mainnet program writes locked",
                detail: "Developer Workstation can inspect mainnet state, but deploy/upgrade/close/authority mutations remain locked."
            ))
        }

        if let latestEvidence = evidence.first {
            findings.append(WorkstationV2Finding(
                id: "evidence",
                severity: latestEvidence.status == .succeeded ? .info : .medium,
                title: "Latest program evidence",
                detail: "\(latestEvidence.cluster.title) \(latestEvidence.operation.title) \(latestEvidence.status.title)",
                evidence: latestEvidence.programID
            ))
        }

        let status: WorkstationV2ReportStatus = findings.contains(where: { $0.severity == .high }) ? .blocked :
            (findings.contains(where: { $0.severity == .medium }) ? .warning : .ready)

        return WorkstationV2Report(
            capability: .projectBrain,
            status: status,
            summary: "\(project.displayName) is a \(project.detectedFramework.rawValue) project with \(toolchain.availableCount)/\(WorkstationToolchainComponent.allCases.count) toolchain components ready.",
            findings: findings,
            nextActions: [
                "Load the project IDL for PDA, drift, and frontend analysis.",
                "Keep build/deploy locked until project trust, dev wallet, localnet/devnet cluster, and fixed command preview all pass."
            ],
            evidence: [project.displayName, DeveloperProjectBrainPath.display(path: project.localPath)]
        )
    }

    static func detectedFileSummary(_ files: WorkstationDetectedFiles) -> String {
        [
            files.anchorToml ? "Anchor.toml" : nil,
            files.cargoToml ? "Cargo.toml" : nil,
            files.packageJSON ? "package.json" : nil,
            files.programDirectoryCount > 0 ? "\(files.programDirectoryCount) program directories" : nil,
            files.targetIDLJSONCount > 0 ? "\(files.targetIDLJSONCount) target IDLs" : nil,
            files.idlJSONCount > 0 ? "\(files.idlJSONCount) idl files" : nil
        ]
        .compactMap { $0 }
        .joined(separator: ", ")
        .ifEmpty("No known Solana project files detected.")
    }
}

enum WorkstationTransactionDebugService {
    static func summarize(input text: String, cluster: WorkstationCluster) -> WorkstationTransactionDebugSummary {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return WorkstationTransactionDebugSummary(
                status: .empty,
                message: "Paste a public signature or encoded transaction fixture. Nothing is decoded until real input is supplied.",
                transactionVersion: nil,
                signatureCount: nil,
                instructionCount: nil,
                programLabels: [],
                signerCount: nil,
                writableCount: nil,
                addressLookupTableCount: nil,
                fingerprint: nil
            )
        }

        do {
            let input = try TransactionStudioInputDetector.detect(trimmed)
            switch input.kind {
            case .signature:
                return WorkstationTransactionDebugSummary(
                    status: .signature,
                    message: "Valid public signature format. Use the read-only getTransaction preset to fetch chain data before decoding.",
                    transactionVersion: nil,
                    signatureCount: 1,
                    instructionCount: nil,
                    programLabels: [],
                    signerCount: nil,
                    writableCount: nil,
                    addressLookupTableCount: nil,
                    fingerprint: input.safePreview
                )
            case .rawTransaction:
                let decoded = try TransactionDecoder.decode(input: input, network: cluster.walletNetwork ?? .devnet)
                return WorkstationTransactionDebugSummary(
                    status: .rawDecoded,
                    message: "Raw transaction decoded locally for review only. No signing or broadcast path exists here.",
                    transactionVersion: decoded.transactionVersion,
                    signatureCount: decoded.signatureCount,
                    instructionCount: decoded.instructions.count,
                    programLabels: decoded.programSummaries.map(\.label),
                    signerCount: decoded.signerSummaries.count,
                    writableCount: decoded.writableAccounts.count,
                    addressLookupTableCount: decoded.addressLookupTables.count,
                    fingerprint: decoded.fingerprint
                )
            case .address:
                return WorkstationTransactionDebugSummary(
                    status: .unsupported,
                    message: "This input is a public address. Use Account Decoder or RPC Playground for account inspection.",
                    transactionVersion: nil,
                    signatureCount: nil,
                    instructionCount: nil,
                    programLabels: [],
                    signerCount: nil,
                    writableCount: nil,
                    addressLookupTableCount: nil,
                    fingerprint: input.safePreview
                )
            case .importHandoff, .unknown:
                return unsupported(reason: "Input kind is not supported by the Workstation transaction debugger.")
            }
        } catch let error as TransactionStudioDecodeError {
            if case .forbiddenField(let field) = error {
                return WorkstationTransactionDebugSummary(
                    status: .forbidden,
                    message: "Input was blocked because it appears to contain private material: \(field).",
                    transactionVersion: nil,
                    signatureCount: nil,
                    instructionCount: nil,
                    programLabels: [],
                    signerCount: nil,
                    writableCount: nil,
                    addressLookupTableCount: nil,
                    fingerprint: nil
                )
            }
            return unsupported(reason: error.localizedDescription)
        } catch {
            return unsupported(reason: error.localizedDescription)
        }
    }

    private static func unsupported(reason: String) -> WorkstationTransactionDebugSummary {
        WorkstationTransactionDebugSummary(
            status: .unsupported,
            message: AgentSafetyRedactor.redact(reason),
            transactionVersion: nil,
            signatureCount: nil,
            instructionCount: nil,
            programLabels: [],
            signerCount: nil,
            writableCount: nil,
            addressLookupTableCount: nil,
            fingerprint: nil
        )
    }
}

enum WorkstationPDAExplorerService {
    static func analyze(idl: WorkstationIDL?, programID: String?, expectedAddress: String?) -> [WorkstationPDAFinding] {
        guard let idl else {
            return [
                WorkstationPDAFinding(
                    instructionName: "Unavailable",
                    accountName: "No IDL",
                    seedSummary: "No PDA seed metadata",
                    derivedAddress: nil,
                    bump: nil,
                    expectedAddress: sanitizedExpectedAddress(expectedAddress),
                    status: .noPDAMetadata,
                    message: "Load an Anchor IDL before PDA analysis can run."
                )
            ]
        }

        let accountsWithPDA = idl.instructions.flatMap { instruction in
            instruction.accounts.compactMap { account -> (WorkstationIDLInstruction, WorkstationIDLInstructionAccount, WorkstationIDLPDA)? in
                guard let pda = account.pda else {
                    return nil
                }
                return (instruction, account, pda)
            }
        }

        guard !accountsWithPDA.isEmpty else {
            return [
                WorkstationPDAFinding(
                    instructionName: idl.name,
                    accountName: "No PDA accounts",
                    seedSummary: "No Anchor PDA metadata was present in the parsed IDL.",
                    derivedAddress: nil,
                    bump: nil,
                    expectedAddress: sanitizedExpectedAddress(expectedAddress),
                    status: .noPDAMetadata,
                    message: "IDL parsed successfully, but it does not expose PDA seed metadata."
                )
            ]
        }

        return accountsWithPDA.map { instruction, account, pda in
            analyzePDA(
                instructionName: instruction.name,
                accountName: account.name,
                pda: pda,
                fallbackProgramID: programID ?? idl.address,
                expectedAddress: expectedAddress
            )
        }
    }

    private static func analyzePDA(
        instructionName: String,
        accountName: String,
        pda: WorkstationIDLPDA,
        fallbackProgramID: String?,
        expectedAddress: String?
    ) -> WorkstationPDAFinding {
        let program = pda.program.flatMap { SolanaAddressValidator.isValidAddress($0) ? $0 : nil } ?? fallbackProgramID
        guard let program, SolanaAddressValidator.isValidAddress(program) else {
            return WorkstationPDAFinding(
                instructionName: instructionName,
                accountName: accountName,
                seedSummary: pda.summary,
                derivedAddress: nil,
                bump: nil,
                expectedAddress: sanitizedExpectedAddress(expectedAddress),
                status: .missingProgramID,
                message: "PDA seed metadata exists, but a concrete program id is required for derivation."
            )
        }

        let seedData: [Data] = pda.seeds.compactMap { seed in
            guard seed.kind == "const" else {
                return nil
            }
            if let constBytes = seed.constBytes {
                return Data(constBytes)
            }
            if let value = seed.valueSummary {
                return Data(value.utf8)
            }
            return nil
        }
        guard seedData.count == pda.seeds.count else {
            return WorkstationPDAFinding(
                instructionName: instructionName,
                accountName: accountName,
                seedSummary: pda.summary,
                derivedAddress: nil,
                bump: nil,
                expectedAddress: sanitizedExpectedAddress(expectedAddress),
                status: .dynamicSeedsUnavailable,
                message: "This PDA uses dynamic account or argument seeds. Enter concrete seed values in a future reviewed flow to derive it."
            )
        }

        do {
            let result = try ProgramDerivedAddress.findProgramAddress(seeds: seedData, programID: program)
            let expected = sanitizedExpectedAddress(expectedAddress)
            let status: WorkstationPDADerivationStatus = expected == nil || expected == result.base58Address ? .derived : .mismatch
            return WorkstationPDAFinding(
                instructionName: instructionName,
                accountName: accountName,
                seedSummary: pda.summary,
                derivedAddress: result.base58Address,
                bump: result.bump,
                expectedAddress: expected,
                status: status,
                message: status == .mismatch
                    ? "Derived PDA does not match the supplied expected account."
                    : "Derived from constant IDL seeds using the selected program id."
            )
        } catch {
            return WorkstationPDAFinding(
                instructionName: instructionName,
                accountName: accountName,
                seedSummary: pda.summary,
                derivedAddress: nil,
                bump: nil,
                expectedAddress: sanitizedExpectedAddress(expectedAddress),
                status: .invalidInput,
                message: error.localizedDescription
            )
        }
    }

    private static func sanitizedExpectedAddress(_ expectedAddress: String?) -> String? {
        guard let value = expectedAddress?.trimmingCharacters(in: .whitespacesAndNewlines),
              SolanaAddressValidator.isValidAddress(value) else {
            return nil
        }
        return value
    }
}

enum WorkstationIDLDriftService {
    static func summarize(idl: WorkstationIDL?, selectedProgramID: String?, evidence: [WorkstationProgramOperationEvidence]) -> WorkstationIDLDriftSummary {
        guard let idl else {
            return WorkstationIDLDriftSummary(
                status: .unavailable,
                idlProgramName: nil,
                idlAddress: nil,
                selectedProgramID: cleanProgramID(selectedProgramID),
                latestEvidenceProgramID: evidence.first?.programID,
                message: "Load an Anchor IDL before drift detection can compare program identifiers."
            )
        }

        let selected = cleanProgramID(selectedProgramID)
        let latest = evidence.first?.programID
        let idlAddress = cleanProgramID(idl.address)
        if let idlAddress, let selected, idlAddress != selected {
            return WorkstationIDLDriftSummary(
                status: .warning,
                idlProgramName: idl.name,
                idlAddress: idlAddress,
                selectedProgramID: selected,
                latestEvidenceProgramID: latest,
                message: "IDL address does not match the selected program id."
            )
        }
        if let idlAddress, let latest, idlAddress != latest {
            return WorkstationIDLDriftSummary(
                status: .warning,
                idlProgramName: idl.name,
                idlAddress: idlAddress,
                selectedProgramID: selected,
                latestEvidenceProgramID: latest,
                message: "IDL address differs from the latest stored deploy evidence program id."
            )
        }
        if idlAddress == nil {
            return WorkstationIDLDriftSummary(
                status: .unavailable,
                idlProgramName: idl.name,
                idlAddress: nil,
                selectedProgramID: selected,
                latestEvidenceProgramID: latest,
                message: "This IDL has no address field, so drift detection can only compare instruction/account shape manually."
            )
        }
        return WorkstationIDLDriftSummary(
            status: .ready,
            idlProgramName: idl.name,
            idlAddress: idlAddress,
            selectedProgramID: selected,
            latestEvidenceProgramID: latest,
            message: "IDL address matches the available selected/evidence program id values."
        )
    }

    private static func cleanProgramID(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              SolanaAddressValidator.isValidAddress(value) else {
            return nil
        }
        return value
    }
}

enum WorkstationSecurityScannerService {
    static func scan(project: WorkstationProject?, cluster: WorkstationCluster, toolchain: WorkstationToolchainSnapshot) -> WorkstationV2Report {
        guard let project else {
            return WorkstationV2Report(
                capability: .securityScanner,
                status: .unavailable,
                summary: "No imported project is available to scan.",
                nextActions: ["Import project metadata first."]
            )
        }
        let scannerReport = try? SecurityScannerService.scan(project: project, projectBrain: nil, idl: nil)
        var findings = (scannerReport?.findings.prefix(8) ?? []).map { finding in
            WorkstationV2Finding(
                id: finding.id,
                severity: WorkstationV2FindingSeverity(securitySeverity: finding.severity),
                title: finding.title,
                detail: finding.detail,
                evidence: finding.evidence
            )
        }

        if project.trustStatus != .trusted {
            findings.append(WorkstationV2Finding(
                id: "untrusted",
                severity: .medium,
                title: "Untrusted project",
                detail: "Build, deploy, test, and package commands are blocked until explicit trust is granted."
            ))
        }
        if cluster == .mainnetBeta {
            findings.append(WorkstationV2Finding(
                id: "mainnet",
                severity: .high,
                title: "Mainnet write lock",
                detail: "Program deploy, upgrade, close, and authority mutation remain locked on mainnet."
            ))
        }
        if !toolchain.isAvailable(.anchor) || !toolchain.isAvailable(.solana) {
            findings.append(WorkstationV2Finding(
                id: "toolchain",
                severity: .medium,
                title: "Toolchain incomplete",
                detail: "Anchor and Solana CLI must be active before program operations can produce real localnet/devnet evidence."
            ))
        }

        let status: WorkstationV2ReportStatus = findings.contains(where: { $0.severity == .high }) ? .blocked :
            (findings.contains(where: { $0.severity == .medium }) ? .warning : .ready)
        return WorkstationV2Report(
            capability: .securityScanner,
            status: status,
            summary: scannerReport?.summary ?? "\(findings.count) project safety findings generated from imported metadata and current cluster/toolchain state.",
            findings: findings,
            nextActions: ["Run the full Security Scanner page for source-line findings and redacted export."]
        )
    }
}

private extension WorkstationV2FindingSeverity {
    init(securitySeverity: SecurityFindingSeverity) {
        switch securitySeverity {
        case .info:
            self = .info
        case .low:
            self = .low
        case .medium:
            self = .medium
        case .high:
            self = .high
        }
    }
}

enum WorkstationFrontendIntegrationService {
    static func report(idl: WorkstationIDL?) -> WorkstationV2Report {
        report(project: nil, projectBrain: nil, idl: idl)
    }

    static func report(
        project: WorkstationProject?,
        projectBrain: DeveloperProjectBrain?,
        idl: WorkstationIDL?
    ) -> WorkstationV2Report {
        if let project,
           let assistantReport = try? FrontendIntegrationService.inspect(project: project, projectBrain: projectBrain, idl: idl) {
            let findings = assistantReport.findings.prefix(10).map { finding in
                WorkstationV2Finding(
                    id: finding.id,
                    severity: WorkstationV2FindingSeverity(frontendSeverity: finding.severity),
                    title: finding.title,
                    detail: finding.detail,
                    evidence: finding.sourceRelativePath ?? finding.evidence
                )
            }
            return WorkstationV2Report(
                capability: .frontendAssistant,
                status: WorkstationV2ReportStatus(frontendStatus: assistantReport.status),
                summary: assistantReport.summary,
                findings: findings,
                nextActions: [
                    "Review warnings before generating frontend drafts.",
                    "Generated files are previewed first and written only after explicit approval."
                ],
                evidence: [
                    "\(assistantReport.scannedFileCount) frontend candidate files scanned",
                    assistantReport.recommendedDependencyStyle
                ]
            )
        }

        guard let idl else {
            return WorkstationV2Report(
                capability: .frontendAssistant,
                status: .unavailable,
                summary: project == nil
                    ? "No project is imported, so frontend integration cannot inspect real app files."
                    : "No IDL is loaded, so integration drafts cannot be generated.",
                nextActions: project == nil
                    ? ["Import a folder project first."]
                    : ["Load an Anchor IDL JSON in IDL Browser."]
            )
        }

        let findings = idl.instructions.prefix(8).map { instruction in
            WorkstationV2Finding(
                id: "instruction-\(instruction.name)",
                severity: .info,
                title: instruction.name,
                detail: "\(instruction.accounts.count) accounts, \(instruction.accounts.filter(\.isSigner).count) signers, \(instruction.accounts.filter(\.isMut).count) writable, \(instruction.args.count) args"
            )
        }
        let accountFindings = idl.accounts.prefix(6).map { account in
            WorkstationV2Finding(
                id: "account-\(account.name)",
                severity: .info,
                title: account.name,
                detail: account.fields.map { "\($0.name): \($0.type)" }.joined(separator: ", ").ifEmpty("No fields"),
                evidence: "Discriminator \(account.discriminatorHex)"
            )
        }
        return WorkstationV2Report(
            capability: .frontendAssistant,
            status: .ready,
            summary: "Generated safe integration notes from \(idl.name). No app UI code or generated client code was written.",
            findings: findings + accountFindings,
            nextActions: [
                "Use these names to verify client instruction builders and account forms.",
                "Keep transaction submission inside reviewed Wallet or Program Manager flows."
            ],
            evidence: [idl.summary]
        )
    }
}

private extension WorkstationV2FindingSeverity {
    init(frontendSeverity: FrontendAssistantSeverity) {
        switch frontendSeverity {
        case .info:
            self = .info
        case .low:
            self = .low
        case .medium:
            self = .medium
        case .high:
            self = .high
        }
    }
}

private extension WorkstationV2ReportStatus {
    init(frontendStatus: FrontendAssistantStatus) {
        switch frontendStatus {
        case .ready:
            self = .ready
        case .warning:
            self = .warning
        case .unavailable:
            self = .unavailable
        case .blocked:
            self = .blocked
        }
    }
}

enum WorkstationReleaseManagerService {
    static func report(
        project: WorkstationProject?,
        idl: WorkstationIDL?,
        evidence: [WorkstationProgramOperationEvidence],
        cluster: WorkstationCluster
    ) -> WorkstationV2Report {
        var findings: [WorkstationV2Finding] = []
        if project?.trustStatus == .trusted {
            findings.append(WorkstationV2Finding(id: "trust", severity: .info, title: "Trust gate", detail: "Project is trusted for fixed command previews."))
        } else {
            findings.append(WorkstationV2Finding(id: "trust", severity: .medium, title: "Trust gate", detail: "Project is not trusted. Release commands remain blocked."))
        }
        if let idl {
            findings.append(WorkstationV2Finding(id: "idl", severity: .info, title: "IDL loaded", detail: idl.summary))
        } else {
            findings.append(WorkstationV2Finding(id: "idl", severity: .low, title: "IDL missing", detail: "Load the target IDL before release review."))
        }
        if let latest = evidence.first, latest.status == .succeeded {
            findings.append(WorkstationV2Finding(id: "evidence", severity: .info, title: "Latest deploy evidence", detail: "\(latest.cluster.title) \(latest.operation.title)", evidence: latest.programID))
        } else {
            findings.append(WorkstationV2Finding(id: "evidence", severity: .medium, title: "Deploy evidence missing", detail: "No successful localnet/devnet program evidence is available."))
        }
        if cluster == .mainnetBeta {
            findings.append(WorkstationV2Finding(id: "mainnet", severity: .high, title: "Mainnet locked", detail: "Release Manager cannot execute mainnet program operations in this phase."))
        }

        let status: WorkstationV2ReportStatus = findings.contains(where: { $0.severity == .high }) ? .blocked :
            (findings.contains(where: { $0.severity == .medium }) ? .warning : .ready)
        return WorkstationV2Report(
            capability: .releaseManager,
            status: status,
            summary: "Release readiness is derived from trust, IDL state, selected cluster, and stored redacted program evidence.",
            findings: findings,
            nextActions: ["Use Program Manager for fixed localnet/devnet previews only."]
        )
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}
