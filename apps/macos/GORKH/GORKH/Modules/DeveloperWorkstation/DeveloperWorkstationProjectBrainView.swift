import SwiftUI

struct DeveloperWorkstationProjectBrainView: View {
    let activeProject: WorkstationProject?
    let report: DeveloperProjectBrain?
    let status: WorkstationDataStatus
    let message: String
    let isScanning: Bool
    let dateFormatter: DateFormatter
    let onRescan: () -> Void
    let onOpenAccountDecoder: () -> Void
    let onValidatePDA: (PDACandidate) -> Void
    let onOpenIDL: (IDLBrain) -> Void
    let onOpenSecurityScanner: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            GorkhPanel("Project Brain") {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        keyValue("Selected project", activeProject?.displayName ?? report?.projectName ?? "Import a project first")
                        keyValue("Scan status", status.title)
                        keyValue("Last scanned", report.map { dateFormatter.string(from: $0.generatedAt) } ?? "Not scanned")
                        keyValue("Trust", trustTitle)
                        HStack(spacing: 8) {
                            WorkstationStatusChip(
                                title: "Read-only",
                                systemImage: "eye",
                                color: GorkhColors.success
                            )
                            WorkstationStatusChip(
                                title: trustTitle,
                                systemImage: trustIsTrusted ? "checkmark.shield" : "lock.shield",
                                color: trustIsTrusted ? GorkhColors.success : GorkhColors.warning
                            )
                        }
                    }

                    Spacer()

                    Button(isScanning ? "Scanning..." : "Rescan Project") {
                        onRescan()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(activeProject == nil || isScanning)
                }

                Text(message)
                    .font(.caption)
                    .foregroundStyle(status == .error ? GorkhColors.warning : GorkhColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Project Brain is a bounded conservative project scanner, not a full compiler/parser. Complex macros, generated code, dynamic PDA seeds, and unusual Anchor patterns may be unsupported. It scans files only and does not run cargo, npm, Anchor, Solana CLI, package scripts, or project commands, even for trusted projects.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let report {
                summaryGrid(report)
                programs(report.programs)
                instructions(report.instructions)
                accounts(report.accounts)
                pdaCandidates(report.pdaCandidates)
                idls(report.idls)
                clients(report.clientCandidates, frontends: report.frontendCandidates)
                tests(report.testCandidates)
                warnings(report.warnings, unsupported: report.unsupportedFindings)
            } else {
                GorkhPanel("No Project Brain Report") {
                    Text("Import a folder project, then select Rescan Project. Zip imports remain metadata-only until extracted by a reviewed safe flow.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var trustTitle: String {
        activeProject?.trustStatus.title ?? report?.trustStatus.title ?? "No project"
    }

    private var trustIsTrusted: Bool {
        activeProject?.trustStatus == .trusted || report?.trustStatus.title == "Trusted"
    }

    private func summaryGrid(_ report: DeveloperProjectBrain) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 10)], spacing: 10) {
            DeveloperWorkstationMetricCard(title: "Project type", value: report.projectType.title, detail: "Confidence: \(report.confidence.title)")
            DeveloperWorkstationMetricCard(title: "Programs", value: "\(report.programs.count)", detail: "Source, Anchor.toml, IDL, artifacts")
            DeveloperWorkstationMetricCard(title: "IDLs", value: "\(report.idls.count)", detail: "target/idl and idl folders")
            DeveloperWorkstationMetricCard(title: "Instructions", value: "\(report.instructions.count)", detail: "\(report.accounts.count) account types")
            DeveloperWorkstationMetricCard(title: "PDAs", value: "\(report.pdaCandidates.count)", detail: "Concrete or unsupported seed hints")
            DeveloperWorkstationMetricCard(title: "Warnings", value: "\(report.warnings.count)", detail: report.warnings.first?.title ?? "No warnings")
        }
    }

    private func programs(_ programs: [ProgramBrain]) -> some View {
        GorkhPanel("Programs") {
            if programs.isEmpty {
                Text("No program module or IDL program was detected.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            }
            ForEach(programs) { program in
                DisclosureGroup(program.name) {
                    keyValue("Path", program.relativePath)
                    keyValue("Language", program.language)
                    keyValue("declare_id", program.programIdFromDeclareId ?? "Unavailable")
                    keyValue("Anchor.toml", program.programIdFromAnchorToml ?? "Unavailable")
                    keyValue("IDL address", program.programIdFromIdl ?? "Unavailable")
                    keyValue("Source files", fallback(program.sourceFiles.joined(separator: ", "), "Unavailable"))
                    keyValue("IDL paths", fallback(program.idlPaths.joined(separator: ", "), "Unavailable"))
                    keyValue("Deploy artifacts", fallback(program.deployArtifacts.joined(separator: ", "), "Unavailable"))
                    ForEach(program.programIdMismatchWarnings) { warning in
                        warningRow(warning)
                    }
                }
                .padding(.vertical, 3)
            }
        }
    }

    private func instructions(_ instructions: [InstructionBrain]) -> some View {
        GorkhPanel("Instructions") {
            if instructions.isEmpty {
                Text("No Anchor instruction functions or IDL instructions were detected.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            }
            ForEach(instructions) { instruction in
                DisclosureGroup(instruction.name) {
                    keyValue("Source", sourceLine(instruction.sourceRelativePath, instruction.sourceLineStart))
                    keyValue("Args", fallback(instruction.args.joined(separator: ", "), "None"))
                    keyValue("Accounts", fallback(instruction.accounts.joined(separator: ", "), "Unavailable"))
                    keyValue("Signers", fallback(instruction.signerAccounts.joined(separator: ", "), "None detected"))
                    keyValue("Writable", fallback(instruction.writableAccounts.joined(separator: ", "), "None detected"))
                    keyValue("PDA hints", fallback(instruction.pdaHints.joined(separator: ", "), "None detected"))
                    keyValue("Confidence", instruction.confidence.title)
                }
                .padding(.vertical, 3)
            }
        }
    }

    private func accounts(_ accounts: [AccountBrain]) -> some View {
        GorkhPanel("Accounts") {
            if accounts.isEmpty {
                Text("No account structs or IDL account types were detected.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            }
            ForEach(accounts) { account in
                DisclosureGroup(account.name) {
                    keyValue("Source", sourceLine(account.sourceRelativePath, account.sourceLineStart))
                    keyValue("Discriminator", account.discriminator ?? "Unavailable")
                    keyValue("IDL type", account.idlTypeRef ?? "Unavailable")
                    keyValue("Fields", fallback(account.fields.joined(separator: ", "), "Unavailable"))
                    keyValue("Confidence", account.confidence.title)
                    Button("Open in Account Decoder") {
                        onOpenAccountDecoder()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.vertical, 3)
            }
        }
    }

    private func pdaCandidates(_ pdaCandidates: [PDACandidate]) -> some View {
        GorkhPanel("PDA Candidates") {
            if pdaCandidates.isEmpty {
                Text("No PDA seed constraints, IDL PDA metadata, or manual PDA calls were detected.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            }
            ForEach(pdaCandidates) { candidate in
                DisclosureGroup(candidate.label) {
                    keyValue("Source", sourceLine(candidate.sourceRelativePath, candidate.sourceLineStart))
                    keyValue("Program id source", candidate.programIdSource ?? "Unavailable")
                    keyValue("Seeds", fallback(candidate.seeds.joined(separator: ", "), "Unavailable"))
                    keyValue("Bump", candidate.bumpUsage ?? "Unavailable")
                    keyValue("Instruction", candidate.instructionName ?? "Unavailable")
                    keyValue("Account type", candidate.accountType ?? "Unavailable")
                    keyValue("Confidence", candidate.confidence.title)
                    if let unsupportedReason = candidate.unsupportedReason {
                        Text(unsupportedReason)
                            .font(.caption)
                            .foregroundStyle(GorkhColors.warning)
                    }
                    Button("Validate PDA") {
                        onValidatePDA(candidate)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.vertical, 3)
            }
        }
    }

    private func idls(_ idls: [IDLBrain]) -> some View {
        GorkhPanel("IDLs") {
            if idls.isEmpty {
                Text("No local IDL JSON was detected under idl/ or target/idl/.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            }
            ForEach(idls) { idl in
                DisclosureGroup(idl.programName) {
                    keyValue("Path", idl.relativePath)
                    keyValue("Program id", idl.programId ?? "Unavailable")
                    keyValue("Instructions", fallback(idl.instructions.joined(separator: ", "), "None"))
                    keyValue("Accounts", fallback(idl.accounts.joined(separator: ", "), "None"))
                    keyValue("Types", fallback(idl.types.joined(separator: ", "), "None"))
                    keyValue("Events", fallback(idl.events.joined(separator: ", "), "None"))
                    Button("Open in IDL Browser") {
                        onOpenIDL(idl)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.vertical, 3)
            }
        }
    }

    private func clients(_ clients: [ClientCandidate], frontends: [FrontendCandidate]) -> some View {
        GorkhPanel("Clients / Frontends") {
            if clients.isEmpty, frontends.isEmpty {
                Text("No generated TypeScript client or frontend integration file was detected in bounded scan paths.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            }
            ForEach(clients) { client in
                keyValue(client.framework, "\(client.relativePath) · stale: \(client.staleComparedToIDL.map { $0 ? "yes" : "no" } ?? "unknown")")
            }
            ForEach(frontends) { frontend in
                DisclosureGroup(frontend.relativePath) {
                    keyValue("Framework", frontend.frameworkHint)
                    ForEach(frontend.warnings) { warning in
                        warningRow(warning)
                    }
                }
            }
        }
    }

    private func tests(_ tests: [TestCandidate]) -> some View {
        GorkhPanel("Tests") {
            if tests.isEmpty {
                Text("No tests were detected under common tests/client paths.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.warning)
            }
            ForEach(tests) { test in
                keyValue(test.kind, test.relativePath)
            }
        }
    }

    private func warnings(_ warnings: [ProjectBrainWarning], unsupported: [UnsupportedFinding]) -> some View {
        GorkhPanel("Warnings") {
            if warnings.isEmpty, unsupported.isEmpty {
                Text("No Project Brain warnings were generated by the bounded scan.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            }
            ForEach(warnings) { warning in
                warningRow(warning)
            }
            ForEach(unsupported) { finding in
                VStack(alignment: .leading, spacing: 4) {
                    Text(finding.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text(finding.reason)
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                    if let path = finding.sourceRelativePath {
                        DeveloperWorkstationScrollingMonospacedText(value: path)
                    }
                }
                .padding(.vertical, 4)
            }
            if !warnings.isEmpty || !unsupported.isEmpty {
                Button("Open Security Scanner") {
                    onOpenSecurityScanner()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func warningRow(_ warning: ProjectBrainWarning) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                WorkstationStatusChip(
                    title: warning.severity.title,
                    systemImage: warning.severity == .high ? "exclamationmark.triangle" : "info.circle",
                    color: warningColor(warning.severity)
                )
                Text(warning.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(GorkhColors.primaryText)
            }
            Text(warning.detail)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            keyValue("Source", sourceLine(warning.sourceRelativePath, warning.line))
            Text(warning.suggestedAction)
                .font(.caption)
                .foregroundStyle(GorkhColors.warning)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }

    private func sourceLine(_ path: String?, _ line: Int?) -> String {
        guard let path else { return "Unavailable" }
        if let line {
            return "\(path):\(line)"
        }
        return path
    }

    private func warningColor(_ severity: ProjectBrainWarningSeverity) -> Color {
        switch severity {
        case .info:
            return GorkhColors.success
        case .warning, .high:
            return GorkhColors.warning
        }
    }

    private func keyValue(_ key: String, _ value: String) -> some View {
        DeveloperWorkstationKeyValueRow(key: key, value: value)
    }

    private func fallback(_ value: String, _ fallback: String) -> String {
        value.isEmpty ? fallback : value
    }
}
