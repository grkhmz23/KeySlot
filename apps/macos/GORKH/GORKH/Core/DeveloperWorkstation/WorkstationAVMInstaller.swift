import Foundation

enum WorkstationAnchorInstallPlanStatus: String, Codable, Equatable {
    case anchorAlreadyAvailable = "anchor_already_available"
    case readyWithAVM = "ready_with_avm"
    case readyToInstallAVMWithCargo = "ready_to_install_avm_with_cargo"
    case blockedMissingCargo = "blocked_missing_cargo"
    case blockedInvalidVersion = "blocked_invalid_version"

    var title: String {
        switch self {
        case .anchorAlreadyAvailable:
            return "Anchor available"
        case .readyWithAVM:
            return "AVM ready"
        case .readyToInstallAVMWithCargo:
            return "Cargo can install AVM"
        case .blockedMissingCargo:
            return "Blocked: Cargo missing"
        case .blockedInvalidVersion:
            return "Blocked: invalid version"
        }
    }
}
struct WorkstationAnchorInstallPlan: Codable, Equatable, Identifiable {
    let id: String
    let pinnedAnchorVersion: String
    let status: WorkstationAnchorInstallPlanStatus
    let message: String
    let commandPreviews: [String]

    var canProceedWithApproval: Bool {
        status == .readyWithAVM || status == .readyToInstallAVMWithCargo
    }
}

enum WorkstationAnchorInstaller {
    static let pinnedAnchorVersion = WorkstationAnchorVersionPolicy.explicitStableCandidate

    static func isValidPinnedVersion(_ version: String) -> Bool {
        WorkstationAnchorVersionPolicy.isFixedCandidate(version)
    }

    static func plan(snapshot: WorkstationToolchainSnapshot, pinnedVersion: String = pinnedAnchorVersion) -> WorkstationAnchorInstallPlan {
        guard isValidPinnedVersion(pinnedVersion) else {
            return WorkstationAnchorInstallPlan(
                id: "anchor-\(pinnedVersion)",
                pinnedAnchorVersion: pinnedVersion,
                status: .blockedInvalidVersion,
                message: "Anchor version must be a fixed approved candidate: latest or \(WorkstationAnchorVersionPolicy.explicitStableCandidate).",
                commandPreviews: []
            )
        }

        if let anchor = snapshot.resolution(for: .anchor), anchor.status == .available {
            return WorkstationAnchorInstallPlan(
                id: "anchor-\(pinnedVersion)",
                pinnedAnchorVersion: pinnedVersion,
                status: .anchorAlreadyAvailable,
                message: "Anchor CLI is already available. KeySlot will verify with anchor --version before build/deploy.",
                commandPreviews: []
            )
        }

        if let avmPath = snapshot.resolution(for: .avm)?.executablePath {
            let selfUpdate = WorkstationCommandBuilders.avmSelfUpdate(avmPath: avmPath)
            let install = WorkstationCommandBuilders.avmInstallAnchor(avmPath: avmPath, anchorVersion: pinnedVersion)
            let use = WorkstationCommandBuilders.avmUseAnchor(avmPath: avmPath, anchorVersion: pinnedVersion)
            return WorkstationAnchorInstallPlan(
                id: "anchor-\(pinnedVersion)",
                pinnedAnchorVersion: pinnedVersion,
                status: .readyWithAVM,
                message: "AVM is available. Try fixed AVM modernization when needed, then run fixed Anchor install/use and verify with anchor --version.",
                commandPreviews: [selfUpdate.redactedPreview, install.redactedPreview, use.redactedPreview]
            )
        }

        if let cargoPath = snapshot.resolution(for: .cargo)?.executablePath {
            let installAVM = WorkstationCommandBuilders.cargoInstallAVM(cargoPath: cargoPath, anchorVersion: pinnedVersion)
            return WorkstationAnchorInstallPlan(
                id: "anchor-\(pinnedVersion)",
                pinnedAnchorVersion: pinnedVersion,
                status: .readyToInstallAVMWithCargo,
                message: "Cargo is available. AVM can be installed from the official Anchor repository with fixed args after explicit tooling-install approval.",
                commandPreviews: [installAVM.redactedPreview, "Verify avm --version, then run fixed AVM install/use commands for Anchor \(pinnedVersion)."]
            )
        }

        return WorkstationAnchorInstallPlan(
            id: "anchor-\(pinnedVersion)",
            pinnedAnchorVersion: pinnedVersion,
            status: .blockedMissingCargo,
            message: "Anchor install is blocked until AVM or Cargo is available.",
            commandPreviews: []
        )
    }
}
