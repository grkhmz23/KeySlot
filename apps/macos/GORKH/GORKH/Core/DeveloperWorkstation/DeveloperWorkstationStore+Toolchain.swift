import Foundation

extension DeveloperWorkstationStore {
    func refreshToolchain() {
        let resolver = WorkstationToolchainResolver()
        toolchainState.toolchainSnapshot = resolver.resolveAll()
        let wizard = WorkstationToolchainInstallWizardSnapshot.build(
            manifest: .d3Default,
            snapshot: toolchainState.toolchainSnapshot
        )
        toolchainState.toolchainPlans = wizard.plans
        toolchainState.anchorInstallPlan = wizard.anchorPlan
        toolchainState.avmUpdatePlan = WorkstationAVMModernizationPlanner.avmUpdatePlan(snapshot: toolchainState.toolchainSnapshot)
        toolchainState.anchorBinaryPlan = WorkstationAVMModernizationPlanner.anchorBinaryInstallPlan(manifest: .d3Default)
        appendActivity(.toolchainChecked, "Toolchain status checked.")
        appendActivity(.toolchainInstallPlanCreated, "Managed toolchain install plans refreshed.")
        appendActivity(.avmInstallPlanCreated, "Anchor/AVM install plan refreshed.")
        appendActivity(.avmUpdatePlanCreated, "AVM modernization plan refreshed.")
        appendActivity(.anchorBinaryInstallPlanCreated, "Anchor binary artifact plan refreshed.")
    }

    func refreshCompatibility() {
        appendActivity(.compatibilityCheckStarted, "Anchor/Rust compatibility check started.")
        let resolver = WorkstationToolchainResolver()
        toolchainState.toolchainSnapshot = resolver.resolveAll()
        let wizard = WorkstationToolchainInstallWizardSnapshot.build(
            manifest: .d3Default,
            snapshot: toolchainState.toolchainSnapshot
        )
        toolchainState.toolchainPlans = wizard.plans
        toolchainState.anchorInstallPlan = wizard.anchorPlan
        toolchainState.avmUpdatePlan = WorkstationAVMModernizationPlanner.avmUpdatePlan(snapshot: toolchainState.toolchainSnapshot)
        toolchainState.anchorBinaryPlan = WorkstationAVMModernizationPlanner.anchorBinaryInstallPlan(manifest: .d3Default)
        let probe = WorkstationCompatibilityProbe().probe(snapshot: toolchainState.toolchainSnapshot)
        toolchainState.compatibilityMatrix = WorkstationCompatibilityMatrix.build(probe: probe)
        toolchainState.anchorStrategy = WorkstationAnchorStrategySelector.select(
            matrix: toolchainState.compatibilityMatrix,
            avmPath: toolchainState.toolchainSnapshot.resolution(for: .avm)?.executablePath,
            rustupPath: WorkstationCompatibilityProbe.resolveExecutable(named: "rustup")
        )
        appendActivity(.compatibilityCheckCompleted, "Anchor/Rust compatibility check completed.", details: ["status": toolchainState.compatibilityMatrix.result.status.rawValue])
        appendActivity(.compatibilityStrategyPrepared, "Anchor activation strategy prepared.", details: ["strategy": toolchainState.anchorStrategy.strategy.rawValue])
    }
}
