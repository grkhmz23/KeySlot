import Foundation

enum WorkstationLocalnetSmokeStatus: String, Codable, Equatable {
    case ready
    case blocked
    case skipped

    var title: String {
        switch self {
        case .ready:
            return "Ready"
        case .blocked:
            return "Blocked"
        case .skipped:
            return "Skipped"
        }
    }
}

struct WorkstationLocalnetSmokePreflight: Codable, Equatable {
    let status: WorkstationLocalnetSmokeStatus
    let blockers: [String]
    let steps: [String]
    let sampleProjectPath: String

    var summary: String {
        if blockers.isEmpty {
            return "Sample localnet smoke can run after explicit approval."
        }
        return "Sample localnet smoke is blocked: \(blockers.joined(separator: "; "))"
    }
}

enum WorkstationLocalnetSmokeRunner {
    static func preflight(
        sampleProjectPath: String,
        snapshot: WorkstationToolchainSnapshot,
        developerWallet: DeveloperWalletMetadata?,
        projectTrusted: Bool,
        startValidator: Bool
    ) -> WorkstationLocalnetSmokePreflight {
        var blockers: [String] = []
        if snapshot.isAvailable(.solana) == false {
            blockers.append("Solana CLI is required.")
        }
        if snapshot.isAvailable(.anchor) == false {
            blockers.append("Anchor CLI is required for sample build.")
        }
        if developerWallet?.status != .ready {
            blockers.append("Developer Workstation wallet is required.")
        }
        if !projectTrusted {
            blockers.append("Sample project must pass the trust gate before build/deploy.")
        }
        if !FileManager.default.fileExists(atPath: sampleProjectPath + "/Anchor.toml") {
            blockers.append("Sample Anchor.toml is missing.")
        }

        let steps = [
            startValidator ? "Start local validator with fixed solana-test-validator args." : "Use existing local validator.",
            "Create transient developer keypair file with chmod 0600.",
            "Fund developer keypair on localnet only.",
            "Run fixed anchor build in the sample project.",
            "Deploy built program to localnet with fixed solana program deploy args.",
            "Verify program show on localnet.",
            "Delete transient keypair and stop only GORKH-started validator."
        ]

        return WorkstationLocalnetSmokePreflight(
            status: blockers.isEmpty ? .ready : .blocked,
            blockers: blockers,
            steps: steps,
            sampleProjectPath: sampleProjectPath
        )
    }
}
