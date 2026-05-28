import SwiftUI

struct DeveloperWorkstationProjectsView: View {
    let activeProject: WorkstationProject?
    let currentProjectBrain: DeveloperProjectBrain?
    @Binding var projectPathInput: String
    @Binding var zipPathInput: String
    @Binding var gitURLInput: String
    @Binding var trustPhrase: String
    let onInspectFolder: () -> Void
    let onInspectZip: () -> Void
    let onPrepareGitClone: () -> Void
    let onTrustProject: () -> Void
    let onOpenProjectBrain: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            GorkhPanel("Project Import") {
                Text("Import is metadata-first. KeySlot does not run scripts, install dependencies, or build automatically.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)

                DeveloperWorkstationLabeledTextField(label: "Folder path", text: $projectPathInput, prompt: "/absolute/path/to/project")
                HStack {
                    Button("Inspect Folder") {
                        onInspectFolder()
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()
                }

                DeveloperWorkstationLabeledTextField(label: "Zip path", text: $zipPathInput, prompt: "/absolute/path/to/project.zip")
                Button("Inspect Zip Metadata") {
                    onInspectZip()
                }
                .buttonStyle(.bordered)

                DeveloperWorkstationLabeledTextField(label: "HTTPS Git URL", text: $gitURLInput, prompt: "https://github.com/example/program.git")
                Button("Prepare Fixed Git Clone") {
                    onPrepareGitClone()
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
                    keyValue("Project Brain", currentProjectBrain?.projectId == activeProject.id.uuidString ? "Scanned \(currentProjectBrain?.programs.count ?? 0) program(s)" : "Not scanned for this project")
                    if !activeProject.warnings.isEmpty {
                        Text(activeProject.warnings.joined(separator: "\n"))
                            .font(.caption)
                            .foregroundStyle(GorkhColors.warning)
                    }
                    Button("Open Project Brain") {
                        onOpenProjectBrain()
                    }
                    .buttonStyle(.bordered)
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
                        onTrustProject()
                    }
                    .disabled(!WorkstationTrustPolicy.canTrust(project: activeProject, phrase: trustPhrase))
                }
            }
        }
    }

    private func keyValue(_ key: String, _ value: String) -> some View {
        DeveloperWorkstationKeyValueRow(key: key, value: value)
    }
}

struct DeveloperWorkstationToolchainView: View {
    let toolchainSnapshot: WorkstationToolchainSnapshot
    let toolchainPlans: [WorkstationToolchainInstallPlan]
    let compatibilityMatrix: WorkstationCompatibilityMatrix
    let anchorInstallPlan: WorkstationAnchorInstallPlan
    let avmUpdatePlan: WorkstationAVMUpdatePlan
    let anchorBinaryPlan: WorkstationAnchorBinaryInstallPlan
    let onRefreshToolchain: () -> Void
    let onRefreshCompatibility: () -> Void

    var body: some View {
        GorkhPanel("Managed Toolchain") {
            HStack {
                Text("Detection checks bundled app resources, versioned Application Support/KeySlot/Toolchains installs, then trusted absolute system paths.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
                Spacer()
                Button("Check Toolchain") {
                    onRefreshToolchain()
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
            compatibilitySnapshot
            Divider().overlay(GorkhColors.border)
            anchorInstallWizard
            Divider().overlay(GorkhColors.border)
            modernAVMPath
        }
    }

    private var compatibilitySnapshot: some View {
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
                onRefreshCompatibility()
            }
            .buttonStyle(.bordered)
        }
    }

    private var anchorInstallWizard: some View {
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
                DeveloperWorkstationScrollingMonospacedText(value: preview)
            }
            Text("AVM/Anchor install is never automatic. Cargo-based AVM install is treated as a trusted tooling install and must be explicitly approved before running.")
                .font(.caption)
                .foregroundStyle(GorkhColors.warning)
        }
    }

    private var modernAVMPath: some View {
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
                DeveloperWorkstationScrollingMonospacedText(value: preview)
            }
            keyValue("Binary artifact", anchorBinaryPlan.verification.title)
            Text(anchorBinaryPlan.message)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
        }
    }

    private func keyValue(_ key: String, _ value: String) -> some View {
        DeveloperWorkstationKeyValueRow(key: key, value: value)
    }
}

struct DeveloperWorkstationCompatibilityView: View {
    let compatibilityMatrix: WorkstationCompatibilityMatrix
    let anchorStrategy: WorkstationAnchorStrategyDecision
    let avmUpdatePlan: WorkstationAVMUpdatePlan
    let anchorBinaryPlan: WorkstationAnchorBinaryInstallPlan
    let onRefreshCompatibility: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            compatibilitySummary
            recommendedStrategy
            avmBinaryFallback
            fixedCandidateMatrix
        }
    }

    private var compatibilitySummary: some View {
        GorkhPanel("Anchor / Rust Compatibility") {
            HStack {
                Text("Compatibility checks use fixed commands only. KeySlot does not mutate the global Rust default and does not install unverified artifacts.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
                Spacer()
                Button("Run Compatibility Check") {
                    onRefreshCompatibility()
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
    }

    private var recommendedStrategy: some View {
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
                DeveloperWorkstationScrollingMonospacedText(value: preview)
            }
            Text("Preparation remains explicit. These previews do not run automatically and do not change the global Rust default.")
                .font(.caption)
                .foregroundStyle(GorkhColors.warning)
        }
    }

    private var avmBinaryFallback: some View {
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
                DeveloperWorkstationScrollingMonospacedText(value: preview)
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
    }

    private var fixedCandidateMatrix: some View {
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
                            DeveloperWorkstationScrollingMonospacedText(value: preview)
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

    private func keyValue(_ key: String, _ value: String) -> some View {
        DeveloperWorkstationKeyValueRow(key: key, value: value)
    }
}
