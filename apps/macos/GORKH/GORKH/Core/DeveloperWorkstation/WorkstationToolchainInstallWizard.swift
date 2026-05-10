import Foundation

struct WorkstationToolchainInstallWizardSnapshot: Codable, Equatable {
    let generatedAt: Date
    let plans: [WorkstationToolchainInstallPlan]
    let anchorPlan: WorkstationAnchorInstallPlan

    var blockedCount: Int {
        plans.filter { !$0.canInstall && $0.status != .managedInstalled && $0.status != .systemDetected && $0.status != .bundledAvailable }.count
    }

    var summary: String {
        if anchorPlan.canProceedWithApproval {
            return "Anchor/AVM tooling can be prepared with explicit approval. Other managed installs remain checksum/artifact gated."
        }
        if anchorPlan.status == .anchorAlreadyAvailable {
            return "Anchor is available. Managed archive installs remain checksum/artifact gated."
        }
        return "Managed install remains blocked where verified artifacts or Cargo/AVM prerequisites are missing."
    }

    static func build(
        manifest: WorkstationToolchainManifest,
        snapshot: WorkstationToolchainSnapshot,
        managedRoot: URL? = nil,
        now: Date = Date()
    ) -> WorkstationToolchainInstallWizardSnapshot {
        let installer = WorkstationToolchainInstaller(manifest: manifest, managedRoot: managedRoot)
        let plans = WorkstationToolchainComponent.allCases.map { component in
            installer.plan(component: component, resolution: snapshot.resolution(for: component))
        }
        return WorkstationToolchainInstallWizardSnapshot(
            generatedAt: now,
            plans: plans,
            anchorPlan: WorkstationAnchorInstaller.plan(snapshot: snapshot)
        )
    }
}
