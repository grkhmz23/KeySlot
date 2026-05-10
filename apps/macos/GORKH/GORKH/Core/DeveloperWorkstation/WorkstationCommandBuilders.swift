import Foundation

enum WorkstationProgramOperation: String, Codable, CaseIterable, Identifiable {
    case anchorBuild = "anchor_build"
    case anchorDeploy = "anchor_deploy"
    case solanaProgramDeploy = "solana_program_deploy"
    case solanaProgramUpgrade = "solana_program_upgrade"
    case solanaProgramShow = "solana_program_show"
    case solanaProgramClose = "solana_program_close"
    case solanaTransferUpgradeAuthority = "solana_transfer_upgrade_authority"
    case solanaRevokeUpgradeAuthority = "solana_revoke_upgrade_authority"

    var id: String { rawValue }

    var title: String {
        rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

enum WorkstationCommandBuilders {
    static func version(component: WorkstationToolchainComponent, executablePath: String) -> WorkstationCommandPlan {
        WorkstationCommandPlan(
            name: "\(component.displayName) version",
            executablePath: executablePath,
            arguments: component.versionArguments
        )
    }

    static func rustupVersion(rustupPath: String) -> WorkstationCommandPlan {
        WorkstationCommandPlan(
            name: "rustup version",
            executablePath: rustupPath,
            arguments: ["--version"]
        )
    }

    static func rustupToolchainList(rustupPath: String) -> WorkstationCommandPlan {
        WorkstationCommandPlan(
            name: "rustup toolchain list",
            executablePath: rustupPath,
            arguments: ["toolchain", "list"]
        )
    }

    static func rustupToolchainInstall(rustupPath: String, rustToolchain: String) -> WorkstationCommandPlan {
        WorkstationCommandPlan(
            name: "Install fixed Rust toolchain",
            executablePath: rustupPath,
            arguments: ["toolchain", "install", rustToolchain]
        )
    }

    static func cargoVersionWithRustToolchain(cargoPath: String, rustToolchain: String) -> WorkstationCommandPlan {
        WorkstationCommandPlan(
            name: "Cargo version with fixed Rust",
            executablePath: cargoPath,
            arguments: ["+\(rustToolchain)", "--version"],
            environmentOverrides: ["RUSTUP_TOOLCHAIN": rustToolchain]
        )
    }

    static func avmList(avmPath: String) -> WorkstationCommandPlan {
        WorkstationCommandPlan(
            name: "AVM list",
            executablePath: avmPath,
            arguments: ["list"]
        )
    }

    static func avmSelfUpdate(avmPath: String) -> WorkstationCommandPlan {
        WorkstationCommandPlan(
            name: "AVM self-update",
            executablePath: avmPath,
            arguments: ["self-update"],
            requiresTrustedProject: false,
            writesToCluster: false
        )
    }

    static func gitClone(url: String, destination: String, gitPath: String = "/usr/bin/git") -> WorkstationCommandPlan {
        WorkstationCommandPlan(
            name: "Git clone",
            executablePath: gitPath,
            arguments: ["clone", "--depth", "1", url, destination],
            requiresTrustedProject: false,
            writesToCluster: false
        )
    }

    static func anchorBuild(anchorPath: String, projectPath: String) -> WorkstationCommandPlan {
        WorkstationCommandPlan(
            name: "Anchor build",
            executablePath: anchorPath,
            arguments: ["build"],
            workingDirectory: projectPath,
            requiresTrustedProject: true,
            writesToCluster: false
        )
    }

    static func anchorDeploy(anchorPath: String, projectPath: String, cluster: WorkstationCluster, keyFilePath: String) -> WorkstationCommandPlan {
        WorkstationCommandPlan(
            name: "Anchor deploy",
            executablePath: anchorPath,
            arguments: ["deploy", "--provider.cluster", cluster.rpcURL.absoluteString, "--provider.wallet", keyFilePath],
            workingDirectory: projectPath,
            cluster: cluster,
            requiresTrustedProject: true,
            writesToCluster: true
        )
    }

    static func solanaProgramDeploy(solanaPath: String, artifactPath: String, cluster: WorkstationCluster, keyFilePath: String) -> WorkstationCommandPlan {
        WorkstationCommandPlan(
            name: "Solana program deploy",
            executablePath: solanaPath,
            arguments: ["program", "deploy", artifactPath, "--url", cluster.rpcURL.absoluteString, "--keypair", keyFilePath],
            cluster: cluster,
            requiresTrustedProject: true,
            writesToCluster: true
        )
    }

    static func solanaProgramUpgrade(solanaPath: String, artifactPath: String, programID: String, cluster: WorkstationCluster, keyFilePath: String) -> WorkstationCommandPlan {
        WorkstationCommandPlan(
            name: "Solana program upgrade",
            executablePath: solanaPath,
            arguments: ["program", "deploy", artifactPath, "--program-id", programID, "--url", cluster.rpcURL.absoluteString, "--keypair", keyFilePath],
            cluster: cluster,
            requiresTrustedProject: true,
            writesToCluster: true
        )
    }

    static func solanaProgramShow(solanaPath: String, programID: String, cluster: WorkstationCluster) -> WorkstationCommandPlan {
        WorkstationCommandPlan(
            name: "Solana program show",
            executablePath: solanaPath,
            arguments: ["program", "show", programID, "--url", cluster.rpcURL.absoluteString],
            cluster: cluster,
            requiresTrustedProject: false,
            writesToCluster: false
        )
    }

    static func solanaProgramClose(solanaPath: String, programID: String, cluster: WorkstationCluster, keyFilePath: String) -> WorkstationCommandPlan {
        WorkstationCommandPlan(
            name: "Solana program close",
            executablePath: solanaPath,
            arguments: ["program", "close", programID, "--url", cluster.rpcURL.absoluteString, "--keypair", keyFilePath],
            cluster: cluster,
            requiresTrustedProject: true,
            writesToCluster: true
        )
    }

    static func solanaTransferUpgradeAuthority(solanaPath: String, programID: String, newAuthority: String, cluster: WorkstationCluster, keyFilePath: String) -> WorkstationCommandPlan {
        WorkstationCommandPlan(
            name: "Solana transfer upgrade authority",
            executablePath: solanaPath,
            arguments: ["program", "set-upgrade-authority", programID, "--new-upgrade-authority", newAuthority, "--url", cluster.rpcURL.absoluteString, "--keypair", keyFilePath],
            cluster: cluster,
            requiresTrustedProject: true,
            writesToCluster: true
        )
    }

    static func solanaRevokeUpgradeAuthority(solanaPath: String, programID: String, cluster: WorkstationCluster, keyFilePath: String) -> WorkstationCommandPlan {
        WorkstationCommandPlan(
            name: "Solana revoke upgrade authority",
            executablePath: solanaPath,
            arguments: ["program", "set-upgrade-authority", programID, "--final", "--url", cluster.rpcURL.absoluteString, "--keypair", keyFilePath],
            cluster: cluster,
            requiresTrustedProject: true,
            writesToCluster: true
        )
    }

    static func cargoBuild(cargoPath: String, projectPath: String) -> WorkstationCommandPlan {
        WorkstationCommandPlan(
            name: "Cargo build",
            executablePath: cargoPath,
            arguments: ["build"],
            workingDirectory: projectPath,
            requiresTrustedProject: true,
            writesToCluster: false
        )
    }

    static func npmInstall(npmPath: String, projectPath: String) -> WorkstationCommandPlan {
        WorkstationCommandPlan(
            name: "npm install",
            executablePath: npmPath,
            arguments: ["install", "--ignore-scripts"],
            workingDirectory: projectPath,
            requiresTrustedProject: true,
            writesToCluster: false
        )
    }

    static func cargoInstallAVM(cargoPath: String, anchorVersion: String) -> WorkstationCommandPlan {
        return WorkstationCommandPlan(
            name: "Install AVM",
            executablePath: cargoPath,
            arguments: [
                "install",
                "--git",
                "https://github.com/solana-foundation/anchor",
                "avm",
                "--force"
            ],
            requiresTrustedProject: false,
            writesToCluster: false
        )
    }

    static func avmInstallAnchor(avmPath: String, anchorVersion: String, rustToolchain: String? = nil) -> WorkstationCommandPlan {
        WorkstationCommandPlan(
            name: "Install Anchor with AVM",
            executablePath: avmPath,
            arguments: ["install", anchorVersion],
            environmentOverrides: rustToolchain.map { ["RUSTUP_TOOLCHAIN": $0] } ?? [:],
            requiresTrustedProject: false,
            writesToCluster: false
        )
    }

    static func avmUseAnchor(avmPath: String, anchorVersion: String) -> WorkstationCommandPlan {
        WorkstationCommandPlan(
            name: "Use Anchor with AVM",
            executablePath: avmPath,
            arguments: ["use", anchorVersion],
            requiresTrustedProject: false,
            writesToCluster: false
        )
    }
}
