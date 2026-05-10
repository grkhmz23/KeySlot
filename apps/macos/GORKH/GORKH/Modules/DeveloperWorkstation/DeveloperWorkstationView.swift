import SwiftUI

struct DeveloperWorkstationView: View {
    @State private var selectedSection: DeveloperWorkstationSection = .overview
    @State private var selectedCluster: WorkstationCluster = .localnet
    @State private var activeProject: WorkstationProject?
    @State private var toolchainSnapshot: WorkstationToolchainSnapshot = .unchecked
    @State private var developerWallet: DeveloperWalletMetadata = .missing
    @State private var activity: [WorkstationActivityEvent] = [
        WorkstationActivityEvent(kind: .workstationOpened, message: "Developer Workstation opened.")
    ]

    @State private var projectPathInput = ""
    @State private var zipPathInput = ""
    @State private var gitURLInput = ""
    @State private var trustPhrase = ""
    @State private var idlText = ""
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
    @State private var programOperation: WorkstationProgramOperation = .solanaProgramShow
    @State private var artifactPath = ""
    @State private var destructivePhrase = ""
    @State private var logState = WorkstationLogStreamState.idle()

    private let keyVault = KeychainDeveloperKeyVault()

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
                overviewCard("Local Validator", value: "Status only", detail: "Start/stop remains locked unless Solana CLI is available and approved.")
                overviewCard("Activity", value: "\(activity.count) events", detail: "Redacted Workstation audit trail.")
            }

            GorkhPanel("Quick Actions") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
                    quickAction("Import Project", systemImage: "folder.badge.plus", target: .projects)
                    quickAction("Open IDL", systemImage: "curlybraces.square", target: .idlBrowser)
                    quickAction("Decode Account", systemImage: "doc.text.magnifyingglass", target: .accountDecoder)
                    quickAction("View Logs", systemImage: "text.alignleft", target: .logs)
                    quickAction("RPC Playground", systemImage: "network", target: .rpcPlayground)
                    quickAction("Airdrop Dev SOL", systemImage: "drop", target: .localnet)
                    quickAction("Build / Deploy", systemImage: "hammer", target: .programManager)
                    quickAction("Offline Signing", systemImage: "externaldrive.badge.lock", target: .offlineSigning)
                }
            }
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
                Text("Detection checks bundled app resources, Application Support/GORKH/Toolchains, then trusted absolute system paths.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
                Spacer()
                Button("Check Toolchain") {
                    toolchainSnapshot = WorkstationToolchainResolver().resolveAll()
                    appendActivity(.toolchainChecked, "Toolchain status checked.")
                }
            }

            ForEach(toolchainSnapshot.resolutions) { resolution in
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
                .font(.callout)
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
            }

            if let parsedIDL {
                GorkhPanel("IDL Summary") {
                    keyValue("Program", parsedIDL.name)
                    keyValue("Version", parsedIDL.version ?? "Unavailable")
                    keyValue("Summary", parsedIDL.summary)
                    DisclosureGroup("Instructions") {
                        ForEach(parsedIDL.instructions) { instruction in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(instruction.name).fontWeight(.semibold)
                                Text("\(instruction.accounts.count) accounts, \(instruction.args.count) args")
                                    .font(.caption)
                                    .foregroundStyle(GorkhColors.secondaryText)
                            }
                            .padding(.vertical, 3)
                        }
                    }
                    DisclosureGroup("Accounts") {
                        ForEach(parsedIDL.accounts) { account in
                            Text("\(account.name): \(account.fields.map(\.name).joined(separator: ", "))")
                                .font(.caption)
                                .foregroundStyle(GorkhColors.secondaryText)
                        }
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
                exactPhrase: destructivePhrase
            )
        )

        return GorkhPanel("Program Manager") {
            Text("Localnet/devnet program ops are gated by project trust, fixed command builders, a separate developer wallet, and explicit approval. Mainnet operations are locked.")
                .font(.caption)
                .foregroundStyle(GorkhColors.warning)

            Picker("Operation", selection: $programOperation) {
                ForEach(WorkstationProgramOperation.allCases) { operation in
                    Text(operation.rawValue.replacingOccurrences(of: "_", with: " ")).tag(operation)
                }
            }
            .pickerStyle(.menu)

            labeledTextField("Program id", text: $programID, prompt: "Program public key")
            labeledTextField("Artifact path", text: $artifactPath, prompt: "target/deploy/program.so")
            labeledTextField("Destructive phrase", text: $destructivePhrase, prompt: WorkstationProgramManager.destructivePhrase)

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

            Text("Command preview is generated only from fixed builders. No raw terminal input or arbitrary flags are accepted in D1.")
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
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
                    idlAccount: idlAccount
                )
            )
            keyValue("Status", result.status.title)
            keyValue("Data length", "\(result.dataLength) bytes")
            keyValue("Raw preview", result.rawPreview.ifEmpty("Unavailable"))
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
            Text("sendTransaction, custom method text, and broad scans are blocked. requestAirdrop is routed through the faucet guard only.")
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
                Text("Status detection uses localnet RPC health. Start/stop remains approval-gated and fixed-command only.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
                WorkstationStatusChip(title: "Start/stop locked in UI foundation", systemImage: "lock", color: GorkhColors.warning)
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
