import SwiftUI
import AppKit

struct DeveloperWorkstationView: View {
    @State private var selectedSection: DeveloperWorkstationSection = .overview
    @State private var selectedCluster: WorkstationCluster = .localnet
    @State private var activeProject: WorkstationProject?
    @State private var toolchainSnapshot: WorkstationToolchainSnapshot = .unchecked
    @State private var toolchainPlans: [WorkstationToolchainInstallPlan] = []
    @State private var anchorInstallPlan: WorkstationAnchorInstallPlan = WorkstationAnchorInstaller.plan(snapshot: .unchecked)
    @State private var compatibilityMatrix: WorkstationCompatibilityMatrix = .unchecked
    @State private var anchorStrategy: WorkstationAnchorStrategyDecision = WorkstationAnchorStrategySelector.select(matrix: .unchecked, avmPath: nil, rustupPath: nil)
    @State private var avmUpdatePlan: WorkstationAVMUpdatePlan = WorkstationAVMModernizationPlanner.avmUpdatePlan(snapshot: .unchecked)
    @State private var anchorBinaryPlan: WorkstationAnchorBinaryInstallPlan = WorkstationAVMModernizationPlanner.anchorBinaryInstallPlan(manifest: .d3Default)
    @State private var developerWallet: DeveloperWalletMetadata = .missing
    @State private var localValidatorStatus: WorkstationLocalValidatorStatus = .unchecked
    @State private var localValidatorResetPhrase = ""
    @State private var localnetSmokePreflight: WorkstationLocalnetSmokePreflight?
    @State private var programEvidence: [WorkstationProgramOperationEvidence] = [.d8LocalnetCertification, .d7LocalnetCertification]
    @State private var evidenceStoreMessage = "Safe evidence is stored as redacted JSON under Application Support."
    @State private var activity: [WorkstationActivityEvent] = [
        WorkstationActivityEvent(kind: .workstationOpened, message: "Developer Workstation opened.")
    ]

    @State private var projectPathInput = ""
    @State private var zipPathInput = ""
    @State private var gitURLInput = ""
    @State private var trustPhrase = ""
    @State private var idlText = ""
    @State private var idlFilter = ""
    @State private var parsedIDL: WorkstationIDL?
    @State private var accountAddress = ""
    @State private var accountDataBase64 = ""
    @State private var programID = ""
    @State private var rpcMethod: WorkstationRPCMethod = .getHealth
    @State private var rpcAddress = ""
    @State private var rpcSignature = ""
    @State private var encodedTransaction = ""
    @State private var faucetAddress = ""
    @State private var faucetAmount = "0.5"
    @State private var faucetStatus = "Airdrop requests are capped and limited to devnet/localnet."
    @State private var programOperation: WorkstationProgramOperation = .solanaProgramShow
    @State private var artifactPath = ""
    @State private var newAuthority = ""
    @State private var destructivePhrase = ""
    @State private var devnetCertificationPhrase = ""
    @State private var programCommandPreview = "Prepare a command preview after toolchain, project, wallet, and cluster checks."
    @State private var logState = WorkstationLogStreamState.idle()

    private let keyVault = KeychainDeveloperKeyVault()
    private let evidenceStore = WorkstationProgramOperationEvidenceStore()

    var body: some View {
        VStack(spacing: 0) {
            header

            Picker("Workstation section", selection: $selectedSection) {
                ForEach(DeveloperWorkstationSection.allCases) { section in
                    Text(section.title).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 18)
            .padding(.bottom, 12)

            Divider().overlay(GorkhColors.border)

            ScrollView {
                sectionBody
                    .padding(18)
            }
        }
        .onAppear {
            developerWallet = keyVault.metadata() ?? .missing
            let stored = evidenceStore.load()
            if !stored.isEmpty {
                programEvidence = stored
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Developer Workstation")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(GorkhColors.primaryText)
                Text("Solana builder workspace for import, IDL review, account decode, logs, RPC reads, compute simulation, and gated localnet/devnet program ops.")
                    .font(.callout)
                    .foregroundStyle(GorkhColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Imported projects start untrusted. Build scripts can run local code, so build/deploy/upgrade/close remain locked until explicit trust and localnet/devnet policy checks pass.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.warning)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                Picker("Cluster", selection: $selectedCluster) {
                    ForEach(WorkstationCluster.allCases) { cluster in
                        Text(cluster.title).tag(cluster)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 180)
                WorkstationStatusChip(
                    title: selectedCluster.programOpsMode.title,
                    systemImage: selectedCluster.programOpsMode == .enabled ? "checkmark.shield" : "lock.shield",
                    color: selectedCluster.programOpsMode == .enabled ? GorkhColors.success : GorkhColors.warning
                )
            }
        }
        .padding(18)
    }

    @ViewBuilder
    private var sectionBody: some View {
        switch selectedSection {
        case .overview:
            overviewSection
        case .projects:
            projectsSection
        case .toolchain:
            toolchainSection
        case .compatibility:
            compatibilitySection
        case .idlBrowser:
            idlSection
        case .programManager:
            programManagerSection
        case .logs:
            logsSection
        case .accountDecoder:
            accountDecoderSection
        case .rpcPlayground:
            rpcSection
        case .computeLab:
            computeSection
        case .localnet:
            localnetSection
        case .offlineSigning:
            offlineSigningSection
        case .activity:
            activitySection
        }
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 12)], spacing: 12) {
                overviewCard("Cluster", value: selectedCluster.title, detail: selectedCluster.rpcURL.absoluteString)
                overviewCard("Project", value: activeProject?.displayName ?? "No project", detail: activeProject?.trustStatus.title ?? "Import a project to begin.")
                overviewCard("Toolchain", value: "\(toolchainSnapshot.availableCount)/\(WorkstationToolchainComponent.allCases.count) ready", detail: "Bundled, managed, then trusted system paths.")
                overviewCard("Developer Wallet", value: developerWallet.status.title, detail: developerWallet.publicAddress.ifEmpty("Separate localnet/devnet wallet only."))
                overviewCard("Local Validator", value: localValidatorStatus.state.title, detail: localValidatorStatus.message)
                overviewCard("Program Evidence", value: programEvidence.first?.status.title ?? "None", detail: programEvidence.first?.programID ?? "No stored program id.")
                overviewCard("Activity", value: "\(activity.count) events", detail: "Redacted Workstation audit trail.")
            }

            GorkhPanel("Quick Actions") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
                    quickAction("Import Project", systemImage: "folder.badge.plus", target: .projects)
                    quickAction("Check Compatibility", systemImage: "checklist.checked", target: .compatibility)
                    quickAction("Open IDL", systemImage: "curlybraces.square", target: .idlBrowser)
                    quickAction("Decode Account", systemImage: "doc.text.magnifyingglass", target: .accountDecoder)
                    quickAction("View Logs", systemImage: "text.alignleft", target: .logs)
                    quickAction("RPC Playground", systemImage: "network", target: .rpcPlayground)
                    quickAction("Airdrop Dev SOL", systemImage: "drop", target: .localnet)
                    quickAction("Build / Deploy", systemImage: "hammer", target: .programManager)
                    quickAction("Offline Signing", systemImage: "externaldrive.badge.lock", target: .offlineSigning)
                }
            }

            programEvidencePanel
        }
    }

    private var projectsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GorkhPanel("Project Import") {
                Text("Import is metadata-first. GORKH does not run scripts, install dependencies, or build automatically.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)

                labeledTextField("Folder path", text: $projectPathInput, prompt: "/absolute/path/to/project")
                HStack {
                    Button("Inspect Folder") {
                        inspectFolder()
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()
                }

                labeledTextField("Zip path", text: $zipPathInput, prompt: "/absolute/path/to/project.zip")
                Button("Inspect Zip Metadata") {
                    inspectZip()
                }
                .buttonStyle(.bordered)

                labeledTextField("HTTPS Git URL", text: $gitURLInput, prompt: "https://github.com/example/program.git")
                Button("Prepare Fixed Git Clone") {
                    prepareGitClone()
                }
                .buttonStyle(.bordered)
            }

            if let activeProject {
                GorkhPanel("Active Project") {
                    keyValue("Name", activeProject.displayName)
                    keyValue("Path", activeProject.localPath)
                    keyValue("Framework", activeProject.detectedFramework.rawValue)
                    keyValue("Trust", activeProject.trustStatus.title)
                    keyValue("IDL files", "\(activeProject.detectedFiles.idlJSONCount + activeProject.detectedFiles.targetIDLJSONCount)")
                    if !activeProject.warnings.isEmpty {
                        Text(activeProject.warnings.joined(separator: "\n"))
                            .font(.caption)
                            .foregroundStyle(GorkhColors.warning)
                    }
                }

                GorkhPanel("Trust Gate") {
                    Text("Trusting a project unlocks build/deploy command previews. Cargo build scripts, npm scripts, proc macros, and Anchor hooks can run local code.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.warning)
                    Text(WorkstationTrustPolicy.requiredPhrase)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                    TextField("Exact trust phrase", text: $trustPhrase)
                        .textFieldStyle(.roundedBorder)
                    Button("Mark Project Trusted") {
                        trustProject()
                    }
                    .disabled(!WorkstationTrustPolicy.canTrust(project: activeProject, phrase: trustPhrase))
                }
            }
        }
    }

    private var toolchainSection: some View {
        GorkhPanel("Managed Toolchain") {
            HStack {
                Text("Detection checks bundled app resources, versioned Application Support/GORKH/Toolchains installs, then trusted absolute system paths.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
                Spacer()
                Button("Check Toolchain") {
                    refreshToolchain()
                }
            }

            ForEach(toolchainSnapshot.resolutions) { resolution in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Text(resolution.component.displayName)
                            .frame(width: 120, alignment: .leading)
                        WorkstationStatusChip(
                            title: resolution.status.title,
                            systemImage: resolution.status == .available ? "checkmark.circle" : "exclamationmark.triangle",
                            color: resolution.status == .available ? GorkhColors.success : GorkhColors.warning
                        )
                        Text(resolution.source.title)
                            .foregroundStyle(GorkhColors.secondaryText)
                        Spacer()
                        Text(resolution.executablePath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? resolution.message)
                            .font(.caption)
                            .foregroundStyle(GorkhColors.secondaryText)
                    }
                    if let plan = toolchainPlans.first(where: { $0.component == resolution.component }) {
                        HStack(spacing: 8) {
                            WorkstationStatusChip(
                                title: plan.status.title,
                                systemImage: plan.canInstall ? "arrow.down.circle" : "lock",
                                color: plan.canInstall ? GorkhColors.success : GorkhColors.warning
                            )
                            Text(plan.message)
                                .font(.caption)
                                .foregroundStyle(GorkhColors.secondaryText)
                            Spacer()
                        }
                    }
                }
                .font(.callout)
                .padding(.vertical, 4)
            }

            Text("Install buttons stay disabled until manifest entries include verified HTTPS sources and sha256 values. No unverified installer execution is available.")
                .font(.caption)
                .foregroundStyle(GorkhColors.warning)

            Divider().overlay(GorkhColors.border)

            VStack(alignment: .leading, spacing: 8) {
                Text("Compatibility Snapshot")
                    .font(.headline)
                WorkstationStatusChip(
                    title: compatibilityMatrix.result.status.title,
                    systemImage: compatibilityMatrix.result.status == .compatible ? "checkmark.circle" : "exclamationmark.triangle",
                    color: compatibilityMatrix.result.status == .compatible ? GorkhColors.success : GorkhColors.warning
                )
                Text(compatibilityMatrix.result.summary)
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
                Button("Run Compatibility Check") {
                    refreshCompatibility()
                }
                .buttonStyle(.bordered)
            }

            Divider().overlay(GorkhColors.border)

            VStack(alignment: .leading, spacing: 8) {
                Text("Anchor / AVM Install Wizard")
                    .font(.headline)
                WorkstationStatusChip(
                    title: anchorInstallPlan.status.title,
                    systemImage: anchorInstallPlan.canProceedWithApproval ? "hammer.circle" : "lock",
                    color: anchorInstallPlan.canProceedWithApproval || anchorInstallPlan.status == .anchorAlreadyAvailable ? GorkhColors.success : GorkhColors.warning
                )
                Text(anchorInstallPlan.message)
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
                ForEach(anchorInstallPlan.commandPreviews, id: \.self) { preview in
                    Text(preview)
                        .font(.caption.monospaced())
                        .foregroundStyle(GorkhColors.secondaryText)
                        .textSelection(.enabled)
                }
                Text("AVM/Anchor install is never automatic. Cargo-based AVM install is treated as a trusted tooling install and must be explicitly approved before running.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.warning)
            }

            Divider().overlay(GorkhColors.border)

            VStack(alignment: .leading, spacing: 8) {
                Text("Modern AVM / Binary Path")
                    .font(.headline)
                WorkstationStatusChip(
                    title: avmUpdatePlan.status.title,
                    systemImage: avmUpdatePlan.canRunWithApproval ? "arrow.triangle.2.circlepath" : "lock",
                    color: avmUpdatePlan.canRunWithApproval ? GorkhColors.success : GorkhColors.warning
                )
                Text(avmUpdatePlan.message)
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
                ForEach(avmUpdatePlan.commandPreviews, id: \.self) { preview in
                    Text(preview)
                        .font(.caption.monospaced())
                        .foregroundStyle(GorkhColors.secondaryText)
                        .textSelection(.enabled)
                }
                keyValue("Binary artifact", anchorBinaryPlan.verification.title)
                Text(anchorBinaryPlan.message)
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            }
        }
    }

    private var compatibilitySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GorkhPanel("Anchor / Rust Compatibility") {
                HStack {
                    Text("Compatibility checks use fixed commands only. GORKH does not mutate the global Rust default and does not install unverified artifacts.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                    Spacer()
                    Button("Run Compatibility Check") {
                        refreshCompatibility()
                    }
                    .buttonStyle(.borderedProminent)
                }

                WorkstationStatusChip(
                    title: compatibilityMatrix.result.status.title,
                    systemImage: compatibilityMatrix.result.status == .compatible ? "checkmark.shield" : "lock.shield",
                    color: compatibilityMatrix.result.status == .compatible ? GorkhColors.success : GorkhColors.warning
                )
                Text(compatibilityMatrix.result.summary)
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], spacing: 10) {
                    compatibilityVersionCard("Rust", compatibilityMatrix.probe.rustcVersion)
                    compatibilityVersionCard("Cargo", compatibilityMatrix.probe.cargoVersion)
                    compatibilityVersionCard("rustup", compatibilityMatrix.probe.rustupVersion)
                    compatibilityVersionCard("AVM", compatibilityMatrix.probe.avmVersion)
                    compatibilityVersionCard("Anchor", compatibilityMatrix.probe.anchorVersion ?? compatibilityMatrix.probe.anchorError)
                    compatibilityVersionCard("Solana", compatibilityMatrix.probe.solanaVersion)
                }

                if !compatibilityMatrix.result.blockers.isEmpty {
                    DisclosureGroup("Blockers") {
                        ForEach(compatibilityMatrix.result.blockers) { blocker in
                            keyValue(blocker.component, blocker.message)
                        }
                    }
                }
            }

            GorkhPanel("Recommended Strategy") {
                WorkstationStatusChip(
                    title: anchorStrategy.status.title,
                    systemImage: anchorStrategy.status == .installPlanAvailable || anchorStrategy.status == .compatible ? "hammer.circle" : "lock",
                    color: anchorStrategy.status == .installPlanAvailable || anchorStrategy.status == .compatible ? GorkhColors.success : GorkhColors.warning
                )
                keyValue("Strategy", anchorStrategy.strategy.rawValue.replacingOccurrences(of: "_", with: " "))
                Text(anchorStrategy.message)
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
                if let environmentPreview = anchorStrategy.environmentPreview {
                    keyValue("Environment", environmentPreview)
                }
                ForEach(anchorStrategy.commandPreviews, id: \.self) { preview in
                    Text(preview)
                        .font(.caption.monospaced())
                        .foregroundStyle(GorkhColors.secondaryText)
                        .textSelection(.enabled)
                }
                Text("Preparation remains explicit. These previews do not run automatically and do not change the global Rust default.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.warning)
            }

            GorkhPanel("AVM Modernization / Binary Fallback") {
                WorkstationStatusChip(
                    title: avmUpdatePlan.status.title,
                    systemImage: avmUpdatePlan.canRunWithApproval ? "arrow.triangle.2.circlepath.circle" : "lock",
                    color: avmUpdatePlan.canRunWithApproval ? GorkhColors.success : GorkhColors.warning
                )
                keyValue("Current AVM", avmUpdatePlan.currentVersion ?? "Unavailable")
                keyValue("Update strategy", avmUpdatePlan.strategy.rawValue.replacingOccurrences(of: "_", with: " "))
                Text(avmUpdatePlan.message)
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
                ForEach(avmUpdatePlan.commandPreviews, id: \.self) { preview in
                    Text(preview)
                        .font(.caption.monospaced())
                        .foregroundStyle(GorkhColors.secondaryText)
                        .textSelection(.enabled)
                }
                Divider().overlay(GorkhColors.border)
                keyValue("Anchor binary", anchorBinaryPlan.verification.title)
                keyValue("Install root", anchorBinaryPlan.installDirectory)
                Text(anchorBinaryPlan.message)
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
                Text("Verified binary install remains disabled until the official release asset URL and SHA-256 are pinned. Source compile failures do not enable unverified downloads.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.warning)
                if compatibilityMatrix.probe.anchorVersion != nil {
                    WorkstationStatusChip(
                        title: "AVM degraded, Anchor active",
                        systemImage: "exclamationmark.triangle",
                        color: GorkhColors.warning
                    )
                    Text("AVM use latest may panic locally, but Anchor CLI is active. This is non-blocking for builds because `anchor --version` succeeds; keep the warning visible until AVM runtime behavior is fixed upstream.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.warning)
                }
            }

            GorkhPanel("Fixed Candidate Matrix") {
                DisclosureGroup("Anchor candidates") {
                    ForEach(compatibilityMatrix.anchorCandidates) { candidate in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(candidate.version)\(candidate.recommended ? " · recommended" : "")")
                                .fontWeight(.semibold)
                            Text(candidate.source)
                                .font(.caption)
                                .foregroundStyle(GorkhColors.secondaryText)
                            Text(candidate.installStrategy)
                                .font(.caption)
                                .foregroundStyle(GorkhColors.secondaryText)
                        }
                        .padding(.vertical, 3)
                    }
                }
                DisclosureGroup("Rust candidates") {
                    ForEach(compatibilityMatrix.rustCandidates) { candidate in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(candidate.version) · \(candidate.installed ? "installed" : "not installed")")
                                .fontWeight(.semibold)
                            Text(candidate.source)
                                .font(.caption)
                                .foregroundStyle(GorkhColors.secondaryText)
                            if let preview = candidate.installCommandPreview {
                                Text(preview)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(GorkhColors.secondaryText)
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(.vertical, 3)
                    }
                }
                DisclosureGroup("Compatibility candidates") {
                    ForEach(compatibilityMatrix.compatibilityCandidates) { candidate in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Anchor \(candidate.anchorVersion) + Rust \(candidate.rustToolchainVersion)")
                                .fontWeight(.semibold)
                            keyValue("Status", candidate.status.title)
                            Text(candidate.installStrategy)
                                .font(.caption)
                                .foregroundStyle(GorkhColors.secondaryText)
                            if let blocker = candidate.blocker {
                                Text(blocker)
                                    .font(.caption)
                                    .foregroundStyle(GorkhColors.warning)
                            }
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
        }
    }

    private var idlSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GorkhPanel("IDL Browser") {
                TextEditor(text: $idlText)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 160)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(GorkhColors.border))
                Button("Parse IDL JSON") {
                    parseIDL()
                }
                .buttonStyle(.borderedProminent)
                labeledTextField("Search IDL", text: $idlFilter, prompt: "instruction, account, type")
            }

            if let parsedIDL {
                GorkhPanel("IDL Summary") {
                    keyValue("Program", parsedIDL.name)
                    keyValue("Version", parsedIDL.version ?? "Unavailable")
                    keyValue("Summary", parsedIDL.summary)
                    DisclosureGroup("Instructions") {
                        ForEach(filteredInstructions(parsedIDL)) { instruction in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(instruction.name).fontWeight(.semibold)
                                Text("\(instruction.accounts.count) accounts, \(instruction.accounts.filter(\.isSigner).count) signers, \(instruction.accounts.filter(\.isMut).count) writable, \(instruction.args.count) args")
                                    .font(.caption)
                                    .foregroundStyle(GorkhColors.secondaryText)
                            }
                            .padding(.vertical, 3)
                        }
                    }
                    DisclosureGroup("Accounts") {
                        ForEach(filteredAccounts(parsedIDL)) { account in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(account.name).fontWeight(.semibold)
                                Text("Discriminator \(account.discriminatorHex)")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(GorkhColors.secondaryText)
                                Text(account.fields.map { "\($0.name): \($0.type)" }.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundStyle(GorkhColors.secondaryText)
                            }
                        }
                    }
                    DisclosureGroup("Types / Events / Errors") {
                        Text("\(parsedIDL.types.count) types, \(parsedIDL.events.count) events, \(parsedIDL.errors.count) errors")
                            .font(.caption)
                            .foregroundStyle(GorkhColors.secondaryText)
                    }
                }
            }
        }
    }

    private var programManagerSection: some View {
        let decision = WorkstationProgramManager.evaluate(
            WorkstationProgramOperationRequest(
                operation: programOperation,
                cluster: selectedCluster,
                project: activeProject,
                toolchain: toolchainSnapshot,
                developerWallet: developerWallet,
                artifactPath: artifactPath.isEmpty ? nil : artifactPath,
                programID: programID.isEmpty ? nil : programID,
                newAuthority: newAuthority.isEmpty ? nil : newAuthority,
                exactPhrase: destructivePhrase
            )
        )

        let devnetDecision = WorkstationDevnetCertificationPolicy.validate(
            cluster: selectedCluster,
            project: activeProject,
            toolchain: toolchainSnapshot,
            developerWallet: developerWallet,
            confirmation: devnetCertificationPhrase
        )

        return VStack(alignment: .leading, spacing: 14) {
            GorkhPanel("Program Manager") {
                Text("Localnet/devnet program ops are gated by project trust, fixed command builders, a separate developer wallet, and explicit approval. Mainnet operations are locked.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.warning)

                Picker("Operation", selection: $programOperation) {
                    ForEach(WorkstationProgramOperation.allCases) { operation in
                        Text(operation.title).tag(operation)
                    }
                }
                .pickerStyle(.menu)

                labeledTextField("Program id", text: $programID, prompt: "Program public key")
                labeledTextField("Artifact path", text: $artifactPath, prompt: "target/deploy/program.so")
                if programOperation == .solanaTransferUpgradeAuthority {
                    labeledTextField("New upgrade authority", text: $newAuthority, prompt: "New authority public key")
                }
                if let requiredPhrase = WorkstationProgramManager.requiredPhrase(for: programOperation) {
                    Text(requiredPhrase)
                        .font(.caption.monospaced())
                        .foregroundStyle(GorkhColors.warning)
                        .textSelection(.enabled)
                    labeledTextField("Exact approval phrase", text: $destructivePhrase, prompt: requiredPhrase)
                } else {
                    Text("This operation still requires explicit approval after preview; no destructive phrase is needed.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                }

                WorkstationStatusChip(
                    title: decision.isAllowed ? "Ready for explicit approval" : "Blocked",
                    systemImage: decision.isAllowed ? "checkmark.shield" : "lock.shield",
                    color: decision.isAllowed ? GorkhColors.success : GorkhColors.warning
                )
                ForEach(decision.reasons, id: \.self) { reason in
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(decision.isAllowed ? GorkhColors.success : GorkhColors.warning)
                }

                Button("Prepare Fixed Command Preview") {
                    prepareProgramCommandPreview()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!decision.isAllowed)

                Text(programCommandPreview)
                    .font(.caption.monospaced())
                    .foregroundStyle(GorkhColors.secondaryText)
                    .textSelection(.enabled)

                Text("Command preview is generated only from fixed builders. No raw terminal input or arbitrary flags are accepted.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)

                Divider().overlay(GorkhColors.border)

                Text("Sample Localnet Smoke")
                    .font(.headline)
                Button("Run Sample Localnet Smoke Preflight") {
                    prepareLocalnetSmokePreflight()
                }
                .buttonStyle(.bordered)
                if let localnetSmokePreflight {
                    WorkstationStatusChip(
                        title: localnetSmokePreflight.status.title,
                        systemImage: localnetSmokePreflight.status == .ready ? "checkmark.circle" : "lock",
                        color: localnetSmokePreflight.status == .ready ? GorkhColors.success : GorkhColors.warning
                    )
                    Text(localnetSmokePreflight.summary)
                        .font(.caption)
                        .foregroundStyle(localnetSmokePreflight.status == .ready ? GorkhColors.success : GorkhColors.warning)
                    DisclosureGroup("Fixed smoke steps") {
                        ForEach(localnetSmokePreflight.steps, id: \.self) { step in
                            Text(step)
                                .font(.caption)
                                .foregroundStyle(GorkhColors.secondaryText)
                        }
                    }
                }
            }

            GorkhPanel("Devnet Certification") {
                Text("Devnet deployment certification is manual and gated. GORKH requires a trusted project, Developer Workstation wallet, active toolchain, Devnet selection, fixed command preview, and exact confirmation.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
                Text(WorkstationDevnetCertificationPolicy.requiredConfirmation)
                    .font(.caption.monospaced())
                    .foregroundStyle(GorkhColors.warning)
                    .textSelection(.enabled)
                labeledTextField("Devnet confirmation", text: $devnetCertificationPhrase, prompt: WorkstationDevnetCertificationPolicy.requiredConfirmation)
                WorkstationStatusChip(
                    title: devnetDecision.isAllowed ? "Devnet certification ready" : "Devnet certification blocked",
                    systemImage: devnetDecision.isAllowed ? "checkmark.shield" : "lock.shield",
                    color: devnetDecision.isAllowed ? GorkhColors.success : GorkhColors.warning
                )
                ForEach(devnetDecision.reasons, id: \.self) { reason in
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(devnetDecision.isAllowed ? GorkhColors.success : GorkhColors.warning)
                }
                Text("Use `scripts/workstation-program-ops-smoke.sh --devnet-sample --confirm-devnet` for the CLI smoke path. It skips safely if the dev wallet is not funded or prerequisites are missing.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            }

            programEvidencePanel
        }
    }

    private var logsSection: some View {
        GorkhPanel("Program Logs") {
            labeledTextField("Program id", text: $programID, prompt: "Program public key")
            HStack {
                Button(logState.isStreaming ? "Stop Stream" : "Start Stream") {
                    toggleLogs()
                }
                .buttonStyle(.borderedProminent)
                WorkstationStatusChip(
                    title: logState.isStreaming ? "Streaming" : "Stopped",
                    systemImage: logState.isStreaming ? "dot.radiowaves.left.and.right" : "pause.circle",
                    color: logState.isStreaming ? GorkhColors.success : GorkhColors.secondaryText
                )
                Spacer()
                Text("Buffer: \(logState.entries.count)/\(logState.maxEntries)")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            }
            if logState.entries.isEmpty {
                Text("No logs captured. Log streaming is read-only and bounded.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            } else {
                ForEach(logState.entries.suffix(20)) { entry in
                    Text(entry.line)
                        .font(.caption.monospaced())
                        .foregroundStyle(GorkhColors.secondaryText)
                }
            }
        }
    }

    private var programEvidencePanel: some View {
        GorkhPanel("Program Operation Evidence") {
            Text(evidenceStoreMessage)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)

            if let latest = programEvidence.first {
                WorkstationStatusChip(
                    title: "\(latest.cluster.title) \(latest.status.title)",
                    systemImage: latest.status == .succeeded ? "checkmark.seal" : "exclamationmark.triangle",
                    color: latest.status == .succeeded ? GorkhColors.success : GorkhColors.warning
                )
                keyValue("Operation", latest.operation.title)
                keyValue("Project", latest.projectName)
                keyValue("Program id", latest.programID ?? "Unavailable")
                keyValue("Signature", latest.signature ?? "Unavailable")
                keyValue("Temp key cleanup", latest.tempKeyCleanupStatus.title)
                keyValue("Command", latest.commandSummary)
                keyValue("IDL", latest.idlPath ?? "Unavailable")
                keyValue("Artifact", latest.artifactPath ?? "Unavailable")
                DisclosureGroup("Tool versions") {
                    ForEach(latest.toolVersions.keys.sorted(), id: \.self) { key in
                        keyValue(key, latest.toolVersions[key] ?? "")
                    }
                }
                DisclosureGroup("Log summary") {
                    Text(latest.logSummary)
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                        .textSelection(.enabled)
                }
                HStack {
                    Button("Copy Program ID") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(latest.programID ?? "", forType: .string)
                        appendActivity(.localnetSmokeEvidenceViewed, "Program id copied from safe evidence.")
                    }
                    .disabled(latest.programID == nil)
                    Button("Open IDL Browser") {
                        selectedSection = .idlBrowser
                        appendActivity(.localnetSmokeEvidenceViewed, "IDL Browser opened from program evidence.")
                    }
                    Button("Open Logs") {
                        if let programID = latest.programID {
                            self.programID = programID
                        }
                        selectedSection = .logs
                        appendActivity(.localnetSmokeEvidenceViewed, "Logs opened from program evidence.")
                    }
                    Button("Persist D8 Evidence") {
                        persistEvidence(.d8LocalnetCertification)
                    }
                }
                .buttonStyle(.bordered)
            } else {
                Text("No safe program-operation evidence has been stored yet.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            }
        }
    }

    private var accountDecoderSection: some View {
        GorkhPanel("Account Decoder") {
            labeledTextField("Account address", text: $accountAddress, prompt: "Solana public key")
            labeledTextField("Account data base64", text: $accountDataBase64, prompt: "Optional account data fixture")
            let idlAccount = parsedIDL?.accounts.first
            let result = WorkstationAccountDecoder.decode(
                WorkstationAccountDecodeRequest(
                    address: accountAddress,
                    ownerProgram: nil,
                    lamports: nil,
                    dataBase64: accountDataBase64.isEmpty ? nil : accountDataBase64,
                    idlAccount: idlAccount,
                    idl: parsedIDL
                )
            )
            keyValue("Status", result.status.title)
            keyValue("Data length", "\(result.dataLength) bytes")
            keyValue("Raw preview", result.rawPreview.ifEmpty("Unavailable"))
            ForEach(result.fields) { field in
                keyValue(field.name, "\(field.value) (\(field.type))")
            }
            Text(result.message)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
        }
    }

    private var rpcSection: some View {
        GorkhPanel("RPC Playground") {
            Picker("Method", selection: $rpcMethod) {
                ForEach(WorkstationRPCMethod.allCases) { method in
                    Text(method.title).tag(method)
                }
            }
            .pickerStyle(.menu)
            keyValue("Risk label", rpcMethod.isReadOnly && !rpcMethod.isBroadScan ? "Read-only preset" : "Blocked or routed through guarded panel")
            labeledTextField("Address", text: $rpcAddress, prompt: "Required for address methods")
            labeledTextField("Signature", text: $rpcSignature, prompt: "Required for signature methods")
            labeledTextField("Encoded transaction/message", text: $encodedTransaction, prompt: "Required for simulate/getFeeForMessage")

            let request = WorkstationRPCPlaygroundRequest(
                method: rpcMethod,
                cluster: selectedCluster,
                address: rpcAddress.isEmpty ? nil : rpcAddress,
                signature: rpcSignature.isEmpty ? nil : rpcSignature,
                encodedTransaction: encodedTransaction.isEmpty ? nil : encodedTransaction,
                amountSOL: nil
            )
            let permission = WorkstationRPCPlaygroundService.validate(request)
            WorkstationStatusChip(
                title: permission.isAllowed ? "Allowed" : "Blocked",
                systemImage: permission.isAllowed ? "checkmark.circle" : "lock",
                color: permission.isAllowed ? GorkhColors.success : GorkhColors.warning
            )
            Text(permission.message)
                .font(.caption)
                .foregroundStyle(permission.isAllowed ? GorkhColors.success : GorkhColors.warning)
            Text("Saved presets are bounded to reviewed read-only methods. sendTransaction, custom method text, and broad scans are blocked. requestAirdrop is routed through the faucet guard only.")
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
        }
    }

    private var computeSection: some View {
        GorkhPanel("Compute Lab") {
            Text("Compute Lab accepts raw transaction fixtures or Transaction Studio handoffs and runs simulation only. No signing or broadcast is available.")
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
            let estimate = WorkstationComputeEstimator.summarize(simulation: .notRun)
            keyValue("Status", estimate.status.rawValue)
            keyValue("Per-instruction estimate", estimate.perInstructionAvailable ? "Available" : "Unavailable")
        }
    }

    private var localnetSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GorkhPanel("Developer Wallet") {
                keyValue("Status", developerWallet.status.title)
                keyValue("Public address", developerWallet.publicAddress.ifEmpty("Not generated"))
                HStack {
                    Button("Generate Developer Wallet") {
                        generateDeveloperWallet()
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Delete Developer Wallet") {
                        deleteDeveloperWallet()
                    }
                    .disabled(developerWallet.status != .ready)
                }
                Text("This wallet is separate from the main GORKH wallet and is for localnet/devnet payer/deployer use only.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            }

            GorkhPanel("Local Validator") {
                Text("Status detection uses localnet RPC health. Start uses solana-test-validator with fixed args and an Application Support ledger path.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
                WorkstationStatusChip(
                    title: localValidatorStatus.state.title,
                    systemImage: localValidatorStatus.state == .running ? "checkmark.circle" : "server.rack",
                    color: localValidatorStatus.state == .running ? GorkhColors.success : GorkhColors.warning
                )
                Text(localValidatorStatus.message)
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
                if let validatorPath = WorkstationToolchainResolver().companionExecutablePath(named: "solana-test-validator", nextTo: .solana) {
                    let ledger = WorkstationLocalValidatorLifecycle.ledgerPath()
                    let plan = WorkstationLocalValidatorCommandBuilder.start(
                        validatorPath: validatorPath,
                        ledgerPath: ledger,
                        reset: false
                    )
                    keyValue("Start preview", plan.redactedPreview)
                    labeledTextField("Reset phrase", text: $localValidatorResetPhrase, prompt: WorkstationLocalValidatorResetPolicy.requiredPhrase)
                    keyValue("Reset allowed", WorkstationLocalValidatorResetPolicy.canReset(phrase: localValidatorResetPhrase) ? "Yes" : "No")
                    keyValue("Stop policy", WorkstationLocalValidatorLifecycle.stopMessage(status: localValidatorStatus))
                } else {
                    Text("solana-test-validator was not found next to a validated Solana CLI executable.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.warning)
                }
            }

            GorkhPanel("Devnet / Localnet Faucet") {
                labeledTextField("Recipient", text: $faucetAddress, prompt: developerWallet.publicAddress.ifEmpty("Public key"))
                labeledTextField("SOL amount", text: $faucetAmount, prompt: "0.5")
                let amount = Double(faucetAmount) ?? 0
                let recipient = faucetAddress.isEmpty ? developerWallet.publicAddress : faucetAddress
                let permission = WorkstationFaucetPolicy.validate(
                    WorkstationFaucetRequest(cluster: selectedCluster, publicAddress: recipient, amountSOL: amount)
                )
                WorkstationStatusChip(
                    title: permission.isAllowed ? "Faucet request allowed" : "Faucet blocked",
                    systemImage: permission.isAllowed ? "drop" : "lock",
                    color: permission.isAllowed ? GorkhColors.success : GorkhColors.warning
                )
                Text(permission.message)
                    .font(.caption)
                    .foregroundStyle(permission.isAllowed ? GorkhColors.success : GorkhColors.warning)
                Button("Request Devnet Airdrop") {
                    requestDevnetAirdrop(recipient: recipient, amountText: faucetAmount, permission: permission)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!permission.isAllowed || selectedCluster != .devnet)
                Text(faucetStatus)
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            }
        }
    }

    private var offlineSigningSection: some View {
        GorkhPanel("Offline Signing Foundation") {
            let state = WorkstationOfflineSigningState.foundation
            keyValue("Status", state.status.rawValue)
            Text(state.message)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
            WorkstationStatusChip(title: "No signing or broadcast in D1", systemImage: "lock.shield", color: GorkhColors.warning)
        }
    }

    private var activitySection: some View {
        GorkhPanel("Workstation Activity") {
            ForEach(activity.prefix(80)) { event in
                HStack(alignment: .top) {
                    Text(event.kind.title)
                        .frame(width: 160, alignment: .leading)
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                    Text(event.message)
                        .font(.caption)
                        .foregroundStyle(GorkhColors.primaryText)
                    Spacer()
                }
            }
        }
    }

    private func overviewCard(_ title: String, value: String, detail: String) -> some View {
        GorkhPanel {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
                Text(value)
                    .font(.headline)
                    .foregroundStyle(GorkhColors.primaryText)
                    .lineLimit(1)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
                    .lineLimit(2)
            }
        }
    }

    private func compatibilityVersionCard(_ title: String, _ value: String?) -> some View {
        GorkhPanel {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
                Text(value ?? "Unavailable")
                    .font(.caption.monospaced())
                    .foregroundStyle(value == nil ? GorkhColors.warning : GorkhColors.primaryText)
                    .lineLimit(3)
                    .textSelection(.enabled)
            }
        }
    }

    private func quickAction(_ title: String, systemImage: String, target: DeveloperWorkstationSection) -> some View {
        Button {
            selectedSection = target
        } label: {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered)
    }

    private func labeledTextField(_ label: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
            TextField(prompt, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func keyValue(_ key: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(key)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
                .frame(width: 130, alignment: .leading)
            Text(value)
                .font(.caption)
                .foregroundStyle(GorkhColors.primaryText)
                .textSelection(.enabled)
            Spacer()
        }
    }

    private func refreshToolchain() {
        let resolver = WorkstationToolchainResolver()
        toolchainSnapshot = resolver.resolveAll()
        let wizard = WorkstationToolchainInstallWizardSnapshot.build(
            manifest: .d3Default,
            snapshot: toolchainSnapshot
        )
        toolchainPlans = wizard.plans
        anchorInstallPlan = wizard.anchorPlan
        avmUpdatePlan = WorkstationAVMModernizationPlanner.avmUpdatePlan(snapshot: toolchainSnapshot)
        anchorBinaryPlan = WorkstationAVMModernizationPlanner.anchorBinaryInstallPlan(manifest: .d3Default)
        appendActivity(.toolchainChecked, "Toolchain status checked.")
        appendActivity(.toolchainInstallPlanCreated, "Managed toolchain install plans refreshed.")
        appendActivity(.avmInstallPlanCreated, "Anchor/AVM install plan refreshed.")
        appendActivity(.avmUpdatePlanCreated, "AVM modernization plan refreshed.")
        appendActivity(.anchorBinaryInstallPlanCreated, "Anchor binary artifact plan refreshed.")
    }

    private func refreshCompatibility() {
        appendActivity(.compatibilityCheckStarted, "Anchor/Rust compatibility check started.")
        let resolver = WorkstationToolchainResolver()
        toolchainSnapshot = resolver.resolveAll()
        let wizard = WorkstationToolchainInstallWizardSnapshot.build(
            manifest: .d3Default,
            snapshot: toolchainSnapshot
        )
        toolchainPlans = wizard.plans
        anchorInstallPlan = wizard.anchorPlan
        avmUpdatePlan = WorkstationAVMModernizationPlanner.avmUpdatePlan(snapshot: toolchainSnapshot)
        anchorBinaryPlan = WorkstationAVMModernizationPlanner.anchorBinaryInstallPlan(manifest: .d3Default)
        let probe = WorkstationCompatibilityProbe().probe(snapshot: toolchainSnapshot)
        compatibilityMatrix = WorkstationCompatibilityMatrix.build(probe: probe)
        anchorStrategy = WorkstationAnchorStrategySelector.select(
            matrix: compatibilityMatrix,
            avmPath: toolchainSnapshot.resolution(for: .avm)?.executablePath,
            rustupPath: WorkstationCompatibilityProbe.resolveExecutable(named: "rustup")
        )
        appendActivity(.compatibilityCheckCompleted, "Anchor/Rust compatibility check completed.", details: ["status": compatibilityMatrix.result.status.rawValue])
        appendActivity(.compatibilityStrategyPrepared, "Anchor activation strategy prepared.", details: ["strategy": anchorStrategy.strategy.rawValue])
    }

    private func filteredInstructions(_ idl: WorkstationIDL) -> [WorkstationIDLInstruction] {
        let query = idlFilter.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            return idl.instructions
        }
        return idl.instructions.filter {
            $0.name.lowercased().contains(query) ||
                $0.args.contains { $0.name.lowercased().contains(query) || $0.type.lowercased().contains(query) } ||
                $0.accounts.contains { $0.name.lowercased().contains(query) }
        }
    }

    private func filteredAccounts(_ idl: WorkstationIDL) -> [WorkstationIDLAccount] {
        let query = idlFilter.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            return idl.accounts
        }
        return idl.accounts.filter {
            $0.name.lowercased().contains(query) ||
                $0.fields.contains { $0.name.lowercased().contains(query) || $0.type.lowercased().contains(query) }
        }
    }

    private func inspectFolder() {
        do {
            let project = try WorkstationProjectImporter().inspectFolder(URL(fileURLWithPath: projectPathInput))
            activeProject = project
            appendActivity(.projectImported, "Project imported from folder.", details: ["source": "folder"])
        } catch {
            appendActivity(.commandBlocked, "Folder import failed: \(error.localizedDescription)")
        }
    }

    private func inspectZip() {
        do {
            let project = try WorkstationProjectImporter().inspectZip(URL(fileURLWithPath: zipPathInput))
            activeProject = project
            appendActivity(.projectImported, "Project zip metadata inspected.", details: ["source": "zip"])
        } catch {
            appendActivity(.commandBlocked, "Zip import failed: \(error.localizedDescription)")
        }
    }

    private func prepareGitClone() {
        do {
            let workspace = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first!
                .appendingPathComponent("GORKH/Workspaces", isDirectory: true)
            let (project, _) = try WorkstationProjectImporter().prepareGitImport(urlString: gitURLInput, workspaceRoot: workspace)
            activeProject = project
            appendActivity(.projectImported, "HTTPS Git clone prepared with fixed args.", details: ["source": "git"])
        } catch {
            appendActivity(.commandBlocked, "Git import blocked: \(error.localizedDescription)")
        }
    }

    private func trustProject() {
        guard let project = activeProject,
              WorkstationTrustPolicy.canTrust(project: project, phrase: trustPhrase) else {
            appendActivity(.commandBlocked, "Project trust phrase did not match.")
            return
        }
        activeProject = WorkstationTrustPolicy.trustedCopy(of: project, phrase: trustPhrase)
        trustPhrase = ""
        appendActivity(.projectTrusted, "Project marked trusted after exact phrase.")
    }

    private func parseIDL() {
        do {
            parsedIDL = try WorkstationIDLParser.parse(string: idlText)
            appendActivity(.idlLoaded, "IDL loaded.")
        } catch {
            appendActivity(.commandBlocked, "IDL parse failed: \(error.localizedDescription)")
        }
    }

    private func prepareProgramCommandPreview() {
        let request = WorkstationProgramOperationRequest(
            operation: programOperation,
            cluster: selectedCluster,
            project: activeProject,
            toolchain: toolchainSnapshot,
            developerWallet: developerWallet,
            artifactPath: artifactPath.isEmpty ? nil : artifactPath,
            programID: programID.isEmpty ? nil : programID,
            newAuthority: newAuthority.isEmpty ? nil : newAuthority,
            exactPhrase: destructivePhrase
        )
        do {
            let plan = try WorkstationProgramOpsRunner.preparePlan(request: request, keypairPath: "/tmp/[redacted-developer-authority].json")
            programCommandPreview = plan.redactedPreview
            let event: WorkstationActivityKind = switch programOperation {
            case .solanaProgramUpgrade:
                .programUpgradePreviewed
            case .solanaProgramClose:
                .programClosePreviewed
            case .solanaTransferUpgradeAuthority:
                .authorityTransferPreviewed
            case .solanaRevokeUpgradeAuthority:
                .authorityRevokePreviewed
            default:
                .commandPreviewPrepared
            }
            appendActivity(
                event,
                "Fixed command preview prepared.",
                details: ["operation": programOperation.rawValue, "cluster": selectedCluster.rawValue]
            )
        } catch {
            programCommandPreview = error.localizedDescription
            if selectedCluster == .mainnetBeta {
                appendActivity(.mainnetProgramOpBlocked, "Mainnet program operation blocked.", details: ["operation": programOperation.rawValue])
            }
            appendActivity(.commandBlocked, "Command preview blocked: \(error.localizedDescription)")
        }
    }

    private func prepareLocalnetSmokePreflight() {
        let sampleProject = WorkstationSampleProject.anchorHelloWorld
        let sampleTrusted = activeProject?.localPath == sampleProject.path && activeProject?.trustStatus == .trusted
        localnetSmokePreflight = WorkstationLocalnetSmokeRunner.preflight(
            sampleProjectPath: sampleProject.path,
            snapshot: toolchainSnapshot,
            developerWallet: developerWallet,
            projectTrusted: sampleTrusted,
            startValidator: true
        )
        appendActivity(.sampleSmokeStarted, "Sample localnet smoke preflight prepared.")
    }

    private func generateDeveloperWallet() {
        do {
            developerWallet = try keyVault.generateDeveloperWallet()
            appendActivity(.devWalletGenerated, "Developer Workstation wallet generated.")
        } catch {
            appendActivity(.commandBlocked, "Developer wallet generation failed.")
        }
    }

    private func deleteDeveloperWallet() {
        let id = developerWallet.id
        do {
            try keyVault.deleteDeveloperWallet(id: id)
            developerWallet = .missing
            appendActivity(.devWalletDeleted, "Developer Workstation wallet deleted.")
        } catch {
            appendActivity(.commandBlocked, "Developer wallet deletion failed.")
        }
    }

    private func persistEvidence(_ evidence: WorkstationProgramOperationEvidence) {
        do {
            programEvidence = try evidenceStore.append(evidence)
            evidenceStoreMessage = "Safe evidence stored at \(WorkstationProgramOperationEvidenceStore.defaultURL().lastPathComponent)."
            appendActivity(
                .programEvidenceStored,
                "Safe program-operation evidence stored.",
                details: ["cluster": evidence.cluster.rawValue, "operation": evidence.operation.rawValue]
            )
        } catch {
            evidenceStoreMessage = "Evidence store failed: \(AgentSafetyRedactor.redact(error.localizedDescription))"
            appendActivity(.commandBlocked, "Program evidence store failed.")
        }
    }

    private func requestDevnetAirdrop(recipient: String, amountText: String, permission: WorkstationRPCPermission) {
        guard permission.isAllowed, selectedCluster == .devnet else {
            faucetStatus = "Airdrop blocked by Workstation faucet policy."
            appendActivity(.devWalletAirdropFailed, "Devnet airdrop blocked by policy.")
            return
        }

        appendActivity(.devWalletAirdropRequested, "Devnet airdrop requested.", details: ["cluster": selectedCluster.rawValue])
        faucetStatus = "Requesting capped devnet airdrop..."
        Task {
            do {
                let signature = try await WorkstationDevnetFaucetService()
                    .requestCappedDevnetFunds(address: recipient, amountText: amountText)
                await MainActor.run {
                    faucetStatus = "Devnet airdrop requested. Signature: \(signature)"
                    appendActivity(.devWalletAirdropSucceeded, "Devnet airdrop succeeded.", details: ["signature": signature])
                }
            } catch {
                await MainActor.run {
                    faucetStatus = "Devnet airdrop failed or rate limited."
                    appendActivity(.devWalletAirdropFailed, "Devnet airdrop failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func toggleLogs() {
        if logState.isStreaming {
            logState = logState.stopped()
            appendActivity(.logsStopped, "Log stream stopped.")
            return
        }
        let permission = WorkstationLogStreamPolicy.canStream(programID: programID)
        guard permission.isAllowed else {
            appendActivity(.commandBlocked, permission.message)
            return
        }
        logState = logState.started(programID: programID)
        appendActivity(.logsStarted, "Log stream started.", details: ["cluster": selectedCluster.rawValue])
    }

    private func appendActivity(_ kind: WorkstationActivityKind, _ message: String, details: [String: String] = [:]) {
        activity.insert(WorkstationActivityEvent(kind: kind, message: message, details: details), at: 0)
        activity = Array(activity.prefix(100))
    }
}

private struct WorkstationStatusChip: View {
    let title: String
    let systemImage: String
    let color: Color

    var body: some View {
        GorkhStatusChip(title: title, systemImage: systemImage, color: color)
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}
