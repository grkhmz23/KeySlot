import Foundation

enum WorkstationCompatibilityStatus: String, Codable, Equatable {
    case unchecked
    case compatible
    case installPlanAvailable = "install_plan_available"
    case blocked
    case unavailable

    var title: String {
        switch self {
        case .unchecked:
            return "Unchecked"
        case .compatible:
            return "Compatible"
        case .installPlanAvailable:
            return "Install plan available"
        case .blocked:
            return "Blocked"
        case .unavailable:
            return "Unavailable"
        }
    }
}

struct WorkstationCompatibilityBlocker: Codable, Equatable, Identifiable {
    let id: String
    let component: String
    let message: String
}

struct WorkstationRustToolchainCandidate: Codable, Equatable, Identifiable {
    let version: String
    let source: String
    let installed: Bool
    let installCommandPreview: String?
    let useEnvironmentPreview: String?

    var id: String { version }
}

struct WorkstationAnchorVersionCandidate: Codable, Equatable, Identifiable {
    let version: String
    let source: String
    let recommended: Bool
    let installStrategy: String
    let verifiedSourceState: String

    var id: String { version }
}

struct WorkstationCompatibilityCandidate: Codable, Equatable, Identifiable {
    let anchorVersion: String
    let rustToolchainVersion: String
    let status: WorkstationCompatibilityStatus
    let installStrategy: String
    let blocker: String?

    var id: String { "\(anchorVersion)-\(rustToolchainVersion)" }
}

struct WorkstationCompatibilityResult: Codable, Equatable {
    let status: WorkstationCompatibilityStatus
    let summary: String
    let recommendedCandidateID: String?
    let blockers: [WorkstationCompatibilityBlocker]
}

struct WorkstationCompatibilityProbeSnapshot: Codable, Equatable {
    let checkedAt: Date
    let rustcVersion: String?
    let cargoVersion: String?
    let rustupVersion: String?
    let rustupToolchains: [String]
    let rustupToolchainListError: String?
    let avmVersion: String?
    let avmVersions: [String]
    let avmListError: String?
    let anchorVersion: String?
    let anchorError: String?
    let solanaVersion: String?
    let validatorVersion: String?

    static let unchecked = WorkstationCompatibilityProbeSnapshot(
        checkedAt: Date(timeIntervalSince1970: 0),
        rustcVersion: nil,
        cargoVersion: nil,
        rustupVersion: nil,
        rustupToolchains: [],
        rustupToolchainListError: nil,
        avmVersion: nil,
        avmVersions: [],
        avmListError: nil,
        anchorVersion: nil,
        anchorError: nil,
        solanaVersion: nil,
        validatorVersion: nil
    )
}

struct WorkstationCompatibilityMatrix: Codable, Equatable {
    let generatedAt: Date
    let probe: WorkstationCompatibilityProbeSnapshot
    let rustCandidates: [WorkstationRustToolchainCandidate]
    let anchorCandidates: [WorkstationAnchorVersionCandidate]
    let compatibilityCandidates: [WorkstationCompatibilityCandidate]
    let result: WorkstationCompatibilityResult

    static let unchecked = WorkstationCompatibilityMatrix.build(probe: .unchecked)

    static func build(probe: WorkstationCompatibilityProbeSnapshot, now: Date = Date()) -> WorkstationCompatibilityMatrix {
        let rustupPath = WorkstationCompatibilityProbe.resolveExecutable(named: "rustup")
        let rustCandidates = WorkstationRustToolchainPolicy.fixedCandidates.map { candidate in
            WorkstationRustToolchainCandidate(
                version: candidate,
                source: candidate == "stable-aarch64-apple-darwin" ? "Detected stable channel" : "Pinned compatibility candidate",
                installed: probe.rustupToolchains.contains { $0.hasPrefix(candidate) },
                installCommandPreview: rustupPath.flatMap {
                    WorkstationRustToolchainPolicy.installPlan(rustupPath: $0, rustToolchain: candidate)?.redactedPreview
                },
                useEnvironmentPreview: "RUSTUP_TOOLCHAIN=\(candidate)"
            )
        }

        let anchorCandidates = WorkstationAnchorVersionPolicy.fixedCandidates.map { candidate in
            WorkstationAnchorVersionCandidate(
                version: candidate,
                source: candidate == "0.31.1" ? "Official Anchor release candidate" : "Existing D3/D4 pinned candidate",
                recommended: candidate == WorkstationAnchorVersionPolicy.recommendedCandidate,
                installStrategy: "AVM fixed install/use; prebuilt artifact remains blocked without sha256",
                verifiedSourceState: "Official source known; no prebuilt artifact checksum pinned"
            )
        }

        let matrixCandidates = [
            WorkstationCompatibilityCandidate(
                anchorVersion: WorkstationAnchorVersionPolicy.recommendedCandidate,
                rustToolchainVersion: WorkstationRustToolchainPolicy.compatibilityPinnedToolchain,
                status: probe.rustupVersion == nil ? .blocked : .installPlanAvailable,
                installStrategy: "Install pinned Rust toolchain with rustup, run AVM install/use with RUSTUP_TOOLCHAIN override, then verify anchor --version.",
                blocker: probe.rustupVersion == nil ? "rustup is missing; GORKH will not install Rust via bootstrap scripts." : nil
            ),
            WorkstationCompatibilityCandidate(
                anchorVersion: WorkstationAnchorInstaller.pinnedAnchorVersion,
                rustToolchainVersion: WorkstationRustToolchainPolicy.compatibilityPinnedToolchain,
                status: probe.rustupVersion == nil ? .blocked : .installPlanAvailable,
                installStrategy: "Retry existing Anchor 0.30.1 candidate with pinned Rust environment only.",
                blocker: probe.rustupVersion == nil ? "rustup is missing; pinned Rust toolchain cannot be prepared." : nil
            ),
            WorkstationCompatibilityCandidate(
                anchorVersion: WorkstationAnchorInstaller.pinnedAnchorVersion,
                rustToolchainVersion: probe.rustcVersion ?? "current",
                status: .blocked,
                installStrategy: "Use current Rust/Cargo.",
                blocker: "D4 showed Anchor 0.30.1 fails to compile under the current Rust/Cargo toolchain."
            )
        ]

        var blockers: [WorkstationCompatibilityBlocker] = []
        if let anchorError = probe.anchorError {
            blockers.append(WorkstationCompatibilityBlocker(id: "anchor", component: "Anchor", message: anchorError))
        } else if probe.anchorVersion == nil {
            blockers.append(WorkstationCompatibilityBlocker(id: "anchor", component: "Anchor", message: "Anchor CLI is not active."))
        }
        if let avmListError = probe.avmListError {
            blockers.append(WorkstationCompatibilityBlocker(id: "avm-list", component: "AVM", message: avmListError))
        }
        if probe.rustupVersion == nil {
            blockers.append(WorkstationCompatibilityBlocker(id: "rustup", component: "Rust", message: "rustup is missing; pinned Rust install/use cannot be prepared."))
        }

        let status: WorkstationCompatibilityStatus
        let summary: String
        let recommendedID: String?
        if probe.anchorVersion != nil {
            status = .compatible
            summary = "Anchor CLI is active. Full localnet smoke can be attempted."
            recommendedID = nil
        } else if probe.rustupVersion != nil {
            status = .installPlanAvailable
            summary = "Anchor is blocked, but a fixed Rust pin plus fixed Anchor candidate plan can be prepared without changing the global Rust default."
            recommendedID = "\(WorkstationAnchorVersionPolicy.recommendedCandidate)-\(WorkstationRustToolchainPolicy.compatibilityPinnedToolchain)"
        } else {
            status = .blocked
            summary = "Anchor remains blocked. A verified prebuilt artifact or rustup-managed pinned toolchain is required."
            recommendedID = nil
        }

        return WorkstationCompatibilityMatrix(
            generatedAt: now,
            probe: probe,
            rustCandidates: rustCandidates,
            anchorCandidates: anchorCandidates,
            compatibilityCandidates: matrixCandidates,
            result: WorkstationCompatibilityResult(
                status: status,
                summary: summary,
                recommendedCandidateID: recommendedID,
                blockers: blockers
            )
        )
    }
}

enum WorkstationRustToolchainPolicy {
    static let compatibilityPinnedToolchain = "1.79.0"
    static let fixedCandidates = ["1.79.0", "stable-aarch64-apple-darwin"]
    static let environmentKey = "RUSTUP_TOOLCHAIN"

    static func isFixedCandidate(_ version: String) -> Bool {
        fixedCandidates.contains(version)
    }

    static func installPlan(rustupPath: String, rustToolchain: String) -> WorkstationCommandPlan? {
        guard rustToolchain == compatibilityPinnedToolchain else {
            return nil
        }
        return WorkstationCommandBuilders.rustupToolchainInstall(rustupPath: rustupPath, rustToolchain: rustToolchain)
    }

    static func validateEnvironmentOverrides(_ overrides: [String: String]) throws {
        for (key, value) in overrides {
            guard key == environmentKey, isFixedCandidate(value) else {
                throw WorkstationCommandValidationError.unsafeArgument("\(key)=\(value)")
            }
        }
    }
}

enum WorkstationAnchorVersionPolicy {
    static let recommendedCandidate = "0.31.1"
    static let fixedCandidates = ["0.31.1", "0.30.1"]

    static func isFixedCandidate(_ version: String) -> Bool {
        fixedCandidates.contains(version)
    }
}

enum WorkstationAnchorActivationStrategy: String, Codable, Equatable {
    case useExistingAnchor = "use_existing_anchor"
    case avmCurrentRust = "avm_current_rust"
    case avmPinnedRust = "avm_pinned_rust"
    case verifiedPrebuiltArtifactBlocked = "verified_prebuilt_artifact_blocked"
    case blocked
}

struct WorkstationAnchorStrategyDecision: Codable, Equatable {
    let strategy: WorkstationAnchorActivationStrategy
    let status: WorkstationCompatibilityStatus
    let message: String
    let commandPreviews: [String]
    let environmentPreview: String?
}

enum WorkstationAnchorStrategySelector {
    static func select(matrix: WorkstationCompatibilityMatrix, avmPath: String?, rustupPath: String?) -> WorkstationAnchorStrategyDecision {
        if matrix.probe.anchorVersion != nil {
            return WorkstationAnchorStrategyDecision(
                strategy: .useExistingAnchor,
                status: .compatible,
                message: "Use existing Anchor CLI after anchor --version verification.",
                commandPreviews: [],
                environmentPreview: nil
            )
        }

        guard let avmPath else {
            return WorkstationAnchorStrategyDecision(
                strategy: .verifiedPrebuiltArtifactBlocked,
                status: .blocked,
                message: "AVM is missing. A prebuilt Anchor artifact path remains blocked until official artifact URL and sha256 are pinned.",
                commandPreviews: [],
                environmentPreview: nil
            )
        }

        guard let rustupPath,
              let rustInstall = WorkstationRustToolchainPolicy.installPlan(
                rustupPath: rustupPath,
                rustToolchain: WorkstationRustToolchainPolicy.compatibilityPinnedToolchain
              ) else {
            let avmInstall = WorkstationCommandBuilders.avmInstallAnchor(
                avmPath: avmPath,
                anchorVersion: WorkstationAnchorVersionPolicy.recommendedCandidate
            )
            let avmUse = WorkstationCommandBuilders.avmUseAnchor(
                avmPath: avmPath,
                anchorVersion: WorkstationAnchorVersionPolicy.recommendedCandidate
            )
            return WorkstationAnchorStrategyDecision(
                strategy: .avmCurrentRust,
                status: .blocked,
                message: "AVM is present, but pinned Rust cannot be prepared. Current Rust path is blocked by D4 compile failure risk.",
                commandPreviews: [avmInstall.redactedPreview, avmUse.redactedPreview],
                environmentPreview: nil
            )
        }

        let avmInstall = WorkstationCommandBuilders.avmInstallAnchor(
            avmPath: avmPath,
            anchorVersion: WorkstationAnchorVersionPolicy.recommendedCandidate,
            rustToolchain: WorkstationRustToolchainPolicy.compatibilityPinnedToolchain
        )
        let avmUse = WorkstationCommandBuilders.avmUseAnchor(
            avmPath: avmPath,
            anchorVersion: WorkstationAnchorVersionPolicy.recommendedCandidate
        )
        return WorkstationAnchorStrategyDecision(
            strategy: .avmPinnedRust,
            status: .installPlanAvailable,
            message: "Recommended: prepare pinned Rust \(WorkstationRustToolchainPolicy.compatibilityPinnedToolchain), run fixed AVM install/use for Anchor \(WorkstationAnchorVersionPolicy.recommendedCandidate), then verify anchor --version. This does not change the global Rust default.",
            commandPreviews: [rustInstall.redactedPreview, avmInstall.redactedPreview, avmUse.redactedPreview, "Verify anchor --version"],
            environmentPreview: "RUSTUP_TOOLCHAIN=\(WorkstationRustToolchainPolicy.compatibilityPinnedToolchain)"
        )
    }
}

struct WorkstationCompatibilityProbe {
    let runner: WorkstationCommandRunner

    init(runner: WorkstationCommandRunner = WorkstationCommandRunner(timeoutSeconds: 15)) {
        self.runner = runner
    }

    static func resolveExecutable(
        named executableName: String,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default,
        directories: [String] = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"]
    ) -> String? {
        let pathDirectories = (environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)
            .filter { $0.hasPrefix("/") && !$0.contains("..") && !$0.contains(";") && !$0.contains("|") && !$0.contains("&") }
        for directory in directories + pathDirectories {
            let path = URL(fileURLWithPath: directory).appendingPathComponent(executableName).path
            if URL(fileURLWithPath: path).lastPathComponent == executableName,
               fileManager.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }

    func probe(snapshot: WorkstationToolchainSnapshot, now: Date = Date()) -> WorkstationCompatibilityProbeSnapshot {
        let rustc = snapshot.resolution(for: .rustc)?.executablePath
        let cargo = snapshot.resolution(for: .cargo)?.executablePath
        let avm = snapshot.resolution(for: .avm)?.executablePath
        let anchor = snapshot.resolution(for: .anchor)?.executablePath
        let solana = snapshot.resolution(for: .solana)?.executablePath
        let validator = WorkstationToolchainResolver().companionExecutablePath(named: "solana-test-validator", nextTo: .solana)
        let rustup = Self.resolveExecutable(named: "rustup")

        let rustcVersion = rustc.flatMap { run(WorkstationCommandPlan(name: "rustc version", executablePath: $0, arguments: ["--version"])).successText }
        let cargoVersion = cargo.flatMap { run(WorkstationCommandPlan(name: "cargo version", executablePath: $0, arguments: ["--version"])).successText }
        let rustupVersion = rustup.flatMap { run(WorkstationCommandBuilders.rustupVersion(rustupPath: $0)).successText }
        let rustupList = rustup.map { run(WorkstationCommandBuilders.rustupToolchainList(rustupPath: $0)) }
        let avmVersion = avm.flatMap { run(WorkstationCommandPlan(name: "avm version", executablePath: $0, arguments: ["--version"])).successText }
        let avmList = avm.map { run(WorkstationCommandBuilders.avmList(avmPath: $0)) }
        let anchorResult = anchor.map { run(WorkstationCommandPlan(name: "anchor version", executablePath: $0, arguments: ["--version"])) }
        let solanaVersion = solana.flatMap { run(WorkstationCommandPlan(name: "solana version", executablePath: $0, arguments: ["--version"])).successText }
        let validatorVersion = validator.flatMap { run(WorkstationCommandPlan(name: "validator version", executablePath: $0, arguments: ["--version"])).successText }

        return WorkstationCompatibilityProbeSnapshot(
            checkedAt: now,
            rustcVersion: rustcVersion,
            cargoVersion: cargoVersion,
            rustupVersion: rustupVersion,
            rustupToolchains: rustupList?.successText?.split(separator: "\n").map(String.init) ?? [],
            rustupToolchainListError: rustupList?.failureText,
            avmVersion: avmVersion,
            avmVersions: avmList?.successText?.split(separator: "\n").map(String.init) ?? [],
            avmListError: avmList?.failureText,
            anchorVersion: anchorResult?.successText,
            anchorError: anchorResult?.failureText,
            solanaVersion: solanaVersion,
            validatorVersion: validatorVersion
        )
    }

    private func run(_ plan: WorkstationCommandPlan) -> ProbeCommandOutput {
        let result = runner.run(plan)
        switch result.status {
        case .succeeded:
            return ProbeCommandOutput(successText: result.stdoutSummary.ifEmpty(result.stderrSummary), failureText: nil)
        default:
            return ProbeCommandOutput(successText: nil, failureText: result.stderrSummary.ifEmpty(result.stdoutSummary).ifEmpty("\(plan.name) failed."))
        }
    }
}

private struct ProbeCommandOutput {
    let successText: String?
    let failureText: String?
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}
