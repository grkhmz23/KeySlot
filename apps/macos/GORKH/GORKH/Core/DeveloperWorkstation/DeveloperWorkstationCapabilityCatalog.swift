import Foundation

enum DeveloperWorkstationCapabilityStatus: String, Codable, CaseIterable {
    case operational
    case limited
    case gated
    case detectOnly
    case unsupported
    case unavailable
    case manualQARequired

    var title: String {
        switch self {
        case .operational:
            return "Operational"
        case .limited:
            return "Limited"
        case .gated:
            return "Gated"
        case .detectOnly:
            return "Detected only"
        case .unsupported:
            return "Unsupported"
        case .unavailable:
            return "Unavailable"
        case .manualQARequired:
            return "Manual QA required"
        }
    }
}

enum DeveloperWorkstationCapabilityRisk: String, Codable, CaseIterable {
    case low
    case medium
    case high

    var title: String { rawValue.capitalized }
}

struct DeveloperWorkstationCapability: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let status: DeveloperWorkstationCapabilityStatus
    let risk: DeveloperWorkstationCapabilityRisk
    let summary: String
    let limitations: [String]
    let nextSafeAction: String?
    let relatedSection: DeveloperWorkstationSection?
}

enum DeveloperWorkstationManualQAStatus: String, Codable, CaseIterable {
    case notRun
    case passed
    case failed
    case notApplicable
    case unavailable

    var title: String {
        switch self {
        case .notRun:
            return "Not run"
        case .passed:
            return "Passed"
        case .failed:
            return "Failed"
        case .notApplicable:
            return "Not applicable"
        case .unavailable:
            return "Unavailable"
        }
    }
}

struct DeveloperWorkstationManualQAItem: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let status: DeveloperWorkstationManualQAStatus
    let detail: String
    let relatedSection: DeveloperWorkstationSection?
}

enum DeveloperWorkstationCapabilityCatalog {
    static let capabilities: [DeveloperWorkstationCapability] = [
        DeveloperWorkstationCapability(
            id: "security-scanner",
            title: "Security Scanner",
            status: .limited,
            risk: .medium,
            summary: "Developer Review Assistant for conservative static checks and triage; not a formal audit.",
            limitations: [
                "Can miss vulnerabilities and can produce false positives.",
                "Does not execute code, call external services, or prove exploitability.",
                "Findings need developer review before acting on them."
            ],
            nextSafeAction: "Run scanner after Project Brain and treat findings as review prompts.",
            relatedSection: .securityScanner
        ),
        DeveloperWorkstationCapability(
            id: "project-brain",
            title: "Project Brain",
            status: .limited,
            risk: .low,
            summary: "Bounded conservative project scanner for real files; not a full compiler/parser.",
            limitations: [
                "Complex macros, generated code, dynamic PDA seeds, and unusual Anchor patterns may be unsupported.",
                "Scans are bounded by file count and file size.",
                "Source findings can be low confidence when exact parsing is unavailable."
            ],
            nextSafeAction: "Review warnings and unsupported findings before using derived results.",
            relatedSection: .projectBrain
        ),
        DeveloperWorkstationCapability(
            id: "pda-explorer",
            title: "PDA Explorer",
            status: .limited,
            risk: .low,
            summary: "Manual/concrete seeds derive real PDAs with read-only account checks.",
            limitations: [
                "Dynamic instruction/account-derived seeds require runtime context and may be unavailable.",
                "Cluster existence checks use read-only getAccountInfo only."
            ],
            nextSafeAction: "Use concrete seed values or a transaction debug report with enough context.",
            relatedSection: .pdaExplorer
        ),
        DeveloperWorkstationCapability(
            id: "pda-mismatch-detection",
            title: "PDA mismatch detection",
            status: .limited,
            risk: .medium,
            summary: "Deterministic-only mismatch detection when all seed values are known.",
            limitations: [
                "Incomplete seed context is reported as unavailable instead of guessed.",
                "Dynamic seeds from runtime account data need extra fetched context."
            ],
            nextSafeAction: "Fetch transaction/account context only when needed and keep checks read-only.",
            relatedSection: .pdaExplorer
        ),
        DeveloperWorkstationCapability(
            id: "idl-drift",
            title: "IDL Drift",
            status: .limited,
            risk: .low,
            summary: "Compares real loaded/local IDLs and Project Brain findings.",
            limitations: [
                "On-chain IDL drift is unsupported unless a reviewed read-only fetcher is available.",
                "Generated client freshness is mtime-based and conservative."
            ],
            nextSafeAction: "Compare target/idl output with checked-in IDLs and release evidence.",
            relatedSection: .idlDrift
        ),
        DeveloperWorkstationCapability(
            id: "account-decoder",
            title: "Account Decoder",
            status: .limited,
            risk: .low,
            summary: "Decodes real account data with bounded Anchor IDL/Borsh support.",
            limitations: [
                "Unsupported layouts fall back honestly without fabricated fields.",
                "Nested and vector decoding is bounded to avoid oversized or recursive layouts.",
                "No broad getProgramAccounts scan is used."
            ],
            nextSafeAction: "Load a matching IDL and fetch a specific account.",
            relatedSection: .accountDecoder
        ),
        DeveloperWorkstationCapability(
            id: "transaction-debugger",
            title: "Transaction Debugger",
            status: .limited,
            risk: .low,
            summary: "RPC/log-based debugger for read-only getTransaction review.",
            limitations: [
                "Root-cause suggestions are heuristic unless deterministic evidence is available.",
                "Custom error mapping requires a matching loaded IDL.",
                "Account details are fetched only after explicit read-only request."
            ],
            nextSafeAction: "Load the project IDL before debugging Anchor failures.",
            relatedSection: .transactionDebugger
        ),
        DeveloperWorkstationCapability(
            id: "test-workbench",
            title: "Test Workbench",
            status: .gated,
            risk: .high,
            summary: "Runs fixed test commands only after trust, preview, and explicit approval.",
            limitations: [
                "Tests execute trusted local project code.",
                "Build scripts and test code may run local code.",
                "Only continue if you trust this project."
            ],
            nextSafeAction: "Trust the project, review the fixed preview, then approve the run phrase.",
            relatedSection: .testWorkbench
        ),
        DeveloperWorkstationCapability(
            id: "litesvm",
            title: "LiteSVM",
            status: .detectOnly,
            risk: .medium,
            summary: "Detected only.",
            limitations: ["Execution requires reviewed fixed command builders."],
            nextSafeAction: "Add reviewed fixed command support before enabling execution.",
            relatedSection: .testWorkbench
        ),
        DeveloperWorkstationCapability(
            id: "mollusk",
            title: "Mollusk",
            status: .detectOnly,
            risk: .medium,
            summary: "Detected only.",
            limitations: ["Execution requires reviewed fixed command builders."],
            nextSafeAction: "Add reviewed fixed command support before enabling execution.",
            relatedSection: .testWorkbench
        ),
        DeveloperWorkstationCapability(
            id: "trident",
            title: "Trident",
            status: .detectOnly,
            risk: .medium,
            summary: "Detected only.",
            limitations: ["Execution requires reviewed fixed command builders."],
            nextSafeAction: "Add reviewed fixed command support before enabling execution.",
            relatedSection: .testWorkbench
        ),
        DeveloperWorkstationCapability(
            id: "test-draft-generation",
            title: "Test draft generation",
            status: .limited,
            risk: .medium,
            summary: "Creates skeleton-level drafts only after explicit click.",
            limitations: [
                "Drafts are not guaranteed to compile.",
                "Existing files are not overwritten without explicit approval."
            ],
            nextSafeAction: "Review generated draft content before moving it into the project.",
            relatedSection: .testWorkbench
        ),
        DeveloperWorkstationCapability(
            id: "compute-regression",
            title: "Compute Regression",
            status: .limited,
            risk: .low,
            summary: "Uses real available logs/measurements only.",
            limitations: [
                "No logs means no measurement.",
                "Per-instruction compute is unavailable unless logs expose enough detail.",
                "Baselines come only from existing real measurements."
            ],
            nextSafeAction: "Store a measurement from simulation, transaction debug logs, or test output.",
            relatedSection: .computeRegression
        ),
        DeveloperWorkstationCapability(
            id: "localnet-fixture-snapshot",
            title: "Localnet Fixture/Snapshot Studio",
            status: .unsupported,
            risk: .medium,
            summary: "Unavailable pending policy review.",
            limitations: ["No restore/export is claimed unless implemented."],
            nextSafeAction: "Use Program Manager evidence until snapshot policy is reviewed.",
            relatedSection: .fixtureStudio
        ),
        DeveloperWorkstationCapability(
            id: "release-manager",
            title: "Release Manager",
            status: .limited,
            risk: .medium,
            summary: "Records localnet/devnet release evidence when real evidence is available.",
            limitations: [
                "Release records can be partial when evidence, IDL path, artifact path, upgrade authority, or git metadata is unavailable.",
                "Mainnet program operations remain locked."
            ],
            nextSafeAction: "Run preflight and inspect missing fields before deploy.",
            relatedSection: .releaseManager
        ),
        DeveloperWorkstationCapability(
            id: "devnet-certification",
            title: "Devnet certification",
            status: .manualQARequired,
            risk: .high,
            summary: "Devnet certification is manual/gated and depends on funding, RPC reliability, and explicit approval.",
            limitations: ["No devnet deploy is claimed unless real evidence exists."],
            nextSafeAction: "Fund the separate dev wallet and run the gated devnet smoke path manually.",
            relatedSection: .programManager
        ),
        DeveloperWorkstationCapability(
            id: "mainnet-program-operations",
            title: "Mainnet program operations",
            status: .unsupported,
            risk: .high,
            summary: "Mainnet program deploy/upgrade/close/authority mutation remains intentionally locked.",
            limitations: ["Read-only mainnet inspection may exist; program writes are blocked."],
            nextSafeAction: nil,
            relatedSection: .programManager
        ),
        DeveloperWorkstationCapability(
            id: "avm",
            title: "AVM",
            status: .limited,
            risk: .medium,
            summary: "Anchor CLI can be active while local AVM use latest remains degraded.",
            limitations: ["AVM use latest may panic locally; builds are not blocked if anchor --version succeeds."],
            nextSafeAction: "Prefer verified active Anchor CLI status over AVM use status.",
            relatedSection: .compatibility
        ),
        DeveloperWorkstationCapability(
            id: "developer-agent",
            title: "Developer Agent",
            status: .gated,
            risk: .high,
            summary: "Developer Agent is constrained by typed tools and approval gates; not autonomous.",
            limitations: [
                "Write, execute, and chain-write modes require the same trust and approval gates.",
                "No AI chat is available unless a provider is configured."
            ],
            nextSafeAction: "Use read-only tools first, then approve specific previews when needed.",
            relatedSection: .workstationAgent
        ),
        DeveloperWorkstationCapability(
            id: "ai-provider",
            title: "AI provider",
            status: .unavailable,
            risk: .medium,
            summary: "No AI chat is available unless a provider is configured.",
            limitations: ["Deterministic Workstation tools remain available without fake AI responses."],
            nextSafeAction: "Configure a provider only after reviewing redaction and data boundary policy.",
            relatedSection: .workstationAgent
        ),
        DeveloperWorkstationCapability(
            id: "patch-write-mode",
            title: "Patch/write mode",
            status: .gated,
            risk: .high,
            summary: "Patch and write operations are preview/approval-only and require a trusted project.",
            limitations: ["No overwrite happens without explicit approval."],
            nextSafeAction: "Inspect patch previews before approval.",
            relatedSection: .workstationAgent
        ),
        DeveloperWorkstationCapability(
            id: "tool-history-evidence",
            title: "Tool history/evidence",
            status: .limited,
            risk: .medium,
            summary: "Tool history is a redacted summary, not full forensic replay.",
            limitations: [
                "Logs are bounded and summarized.",
                "Evidence prioritizes privacy over exhaustive replay detail."
            ],
            nextSafeAction: "Use release/debug evidence links for deeper context when available.",
            relatedSection: .activity
        ),
        DeveloperWorkstationCapability(
            id: "redaction",
            title: "Redaction",
            status: .limited,
            risk: .medium,
            summary: "Redaction is heuristic.",
            limitations: [
                "Unknown secret formats may still be risky.",
                "Path summaries trade off debugging detail for privacy."
            ],
            nextSafeAction: "Avoid pasting secrets into project logs, prompts, or evidence fields.",
            relatedSection: .activity
        ),
        DeveloperWorkstationCapability(
            id: "temp-keypair-cleanup",
            title: "Temp keypair cleanup",
            status: .limited,
            risk: .medium,
            summary: "Session cleanup removes stale KeySlot-managed temporary keypair artifacts only.",
            limitations: [
                "Abnormal termination can leave files until the next cleanup pass.",
                "Cleanup is strict to avoid deleting user files."
            ],
            nextSafeAction: "Restart or open Developer Workstation to run stale-artifact cleanup.",
            relatedSection: .localnet
        ),
        DeveloperWorkstationCapability(
            id: "managed-toolchain-packaging",
            title: "Managed toolchain packaging",
            status: .limited,
            risk: .medium,
            summary: "Toolchain availability is environment-dependent until bundled/managed artifacts are verified and SHA-256 pinned.",
            limitations: [
                "No bundled binary availability is claimed without actual app resources.",
                "Unverified managed installs remain blocked."
            ],
            nextSafeAction: "Pin official artifact URLs and SHA-256 before enabling managed installs.",
            relatedSection: .toolchain
        )
    ]

    static let manualQAItems: [DeveloperWorkstationManualQAItem] = [
        DeveloperWorkstationManualQAItem(
            id: "full-localnet-deploy-smoke",
            title: "Full localnet deploy smoke",
            status: .notRun,
            detail: "Run the localnet sample path in the current environment before claiming fresh localnet evidence.",
            relatedSection: .programManager
        ),
        DeveloperWorkstationManualQAItem(
            id: "funded-devnet-deploy-smoke",
            title: "Funded devnet deploy smoke",
            status: .notRun,
            detail: "Requires funded separate Developer Workstation dev wallet, RPC reliability, and explicit approval.",
            relatedSection: .programManager
        ),
        DeveloperWorkstationManualQAItem(
            id: "visual-screenshot-pass",
            title: "Visual screenshot pass",
            status: .notRun,
            detail: "Needs manual macOS window inspection across Developer Workstation pages.",
            relatedSection: .overview
        ),
        DeveloperWorkstationManualQAItem(
            id: "approval-flow-smoke",
            title: "Approval-flow smoke for build/test/deploy",
            status: .notRun,
            detail: "Verify trust, preview, phrase, and blocked-state UI before every execution path.",
            relatedSection: .testWorkbench
        ),
        DeveloperWorkstationManualQAItem(
            id: "transaction-debugger-public-fixture",
            title: "Transaction Debugger public fixture",
            status: .notRun,
            detail: "Fetch a public signature and confirm logs/errors/account mapping are derived from RPC data.",
            relatedSection: .transactionDebugger
        ),
        DeveloperWorkstationManualQAItem(
            id: "rpc-log-quality-smoke",
            title: "RPC/log quality smoke",
            status: .notRun,
            detail: "Verify read-only RPC forms and bounded log output with live cluster responses.",
            relatedSection: .rpcPlayground
        ),
        DeveloperWorkstationManualQAItem(
            id: "ai-live-provider-smoke",
            title: "AI live provider smoke if configured",
            status: .unavailable,
            detail: "Unavailable when no provider is configured; deterministic tools remain usable.",
            relatedSection: .workstationAgent
        ),
        DeveloperWorkstationManualQAItem(
            id: "managed-toolchain-packaging",
            title: "Managed toolchain packaging verification",
            status: .notRun,
            detail: "Requires verified bundled/managed artifacts and SHA-256 pins.",
            relatedSection: .toolchain
        ),
        DeveloperWorkstationManualQAItem(
            id: "temp-keypair-abnormal-cleanup",
            title: "Temp keypair abnormal-termination cleanup validation",
            status: .notRun,
            detail: "Needs manual abnormal-termination test plus automated stale-file coverage.",
            relatedSection: .localnet
        )
    ]
}
