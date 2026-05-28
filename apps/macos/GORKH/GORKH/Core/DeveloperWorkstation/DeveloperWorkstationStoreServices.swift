import Foundation

protocol DeveloperFaucetServicing {
    func requestCappedDevnetFunds(address: String, amountText: String) async throws -> String
}

struct LiveDeveloperFaucetService: DeveloperFaucetServicing {
    private let service: WorkstationDevnetFaucetService

    init(service: WorkstationDevnetFaucetService = WorkstationDevnetFaucetService()) {
        self.service = service
    }

    func requestCappedDevnetFunds(address: String, amountText: String) async throws -> String {
        try await service.requestCappedDevnetFunds(address: address, amountText: amountText)
    }
}

protocol DeveloperProjectBrainScanning {
    func scan(project: WorkstationProject) async throws -> DeveloperProjectBrain
}

struct LiveDeveloperProjectBrainScanner: DeveloperProjectBrainScanning {
    func scan(project: WorkstationProject) async throws -> DeveloperProjectBrain {
        try await DeveloperProjectBrainService.scan(project: project)
    }
}

protocol DeveloperIDLDriftComparing {
    func compare(source: WorkstationIDL, target: WorkstationIDL, sourceLabel: String, targetLabel: String) -> WorkstationIDLDriftReport
}

struct LiveDeveloperIDLDriftService: DeveloperIDLDriftComparing {
    func compare(source: WorkstationIDL, target: WorkstationIDL, sourceLabel: String, targetLabel: String) -> WorkstationIDLDriftReport {
        WorkstationIDLDriftService.compare(
            source: source,
            target: target,
            sourceLabel: sourceLabel,
            targetLabel: targetLabel
        )
    }
}

protocol DeveloperSecurityScanning {
    func scan(
        project: WorkstationProject?,
        projectBrain: DeveloperProjectBrain?,
        idl: WorkstationIDL?,
        releaseRecords: [WorkstationDeploymentReleaseRecord]
    ) throws -> SecurityScanReport
}

struct LiveDeveloperSecurityScanner: DeveloperSecurityScanning {
    func scan(
        project: WorkstationProject?,
        projectBrain: DeveloperProjectBrain?,
        idl: WorkstationIDL?,
        releaseRecords: [WorkstationDeploymentReleaseRecord]
    ) throws -> SecurityScanReport {
        try SecurityScannerService.scan(
            project: project,
            projectBrain: projectBrain,
            idl: idl,
            releaseRecords: releaseRecords
        )
    }
}

protocol DeveloperFrontendAssisting {
    func inspect(project: WorkstationProject?, projectBrain: DeveloperProjectBrain?, idl: WorkstationIDL?) throws -> FrontendAssistantReport
    func prepareDrafts(
        kind: FrontendGeneratedFileKind,
        instructionName: String?,
        project: WorkstationProject?,
        projectBrain: DeveloperProjectBrain?,
        idl: WorkstationIDL?,
        report: FrontendAssistantReport?
    ) throws -> [FrontendGeneratedFileDraft]
    func writeDrafts(
        _ drafts: [FrontendGeneratedFileDraft],
        project: WorkstationProject?,
        approvalPhrase: String,
        selectedInstruction: String?
    ) throws -> FrontendGenerationEvidence
}

struct LiveDeveloperFrontendAssistant: DeveloperFrontendAssisting {
    func inspect(project: WorkstationProject?, projectBrain: DeveloperProjectBrain?, idl: WorkstationIDL?) throws -> FrontendAssistantReport {
        try FrontendIntegrationService.inspect(project: project, projectBrain: projectBrain, idl: idl)
    }

    func prepareDrafts(
        kind: FrontendGeneratedFileKind,
        instructionName: String?,
        project: WorkstationProject?,
        projectBrain: DeveloperProjectBrain?,
        idl: WorkstationIDL?,
        report: FrontendAssistantReport?
    ) throws -> [FrontendGeneratedFileDraft] {
        try FrontendIntegrationService.prepareDrafts(
            kind: kind,
            instructionName: instructionName,
            project: project,
            projectBrain: projectBrain,
            idl: idl,
            report: report
        )
    }

    func writeDrafts(
        _ drafts: [FrontendGeneratedFileDraft],
        project: WorkstationProject?,
        approvalPhrase: String,
        selectedInstruction: String?
    ) throws -> FrontendGenerationEvidence {
        try FrontendIntegrationService.writeDrafts(
            drafts,
            project: project,
            approvalPhrase: approvalPhrase,
            selectedInstruction: selectedInstruction
        )
    }
}

protocol DeveloperReleaseManaging {
    func preflight(_ input: WorkstationDeploymentPreflightInput) -> WorkstationDeploymentPreflightReport
    func makeReleaseRecord(
        evidence: WorkstationProgramOperationEvidence,
        project: WorkstationProject?,
        artifactURL: URL?,
        idlURL: URL?,
        gitCommit: String?,
        gitDirtyStatus: String?,
        upgradeAuthorityPubkey: String?
    ) throws -> WorkstationDeploymentReleaseRecord
}

struct LiveDeveloperReleaseManager: DeveloperReleaseManaging {
    func preflight(_ input: WorkstationDeploymentPreflightInput) -> WorkstationDeploymentPreflightReport {
        WorkstationDeploymentReleaseService.preflight(input)
    }

    func makeReleaseRecord(
        evidence: WorkstationProgramOperationEvidence,
        project: WorkstationProject?,
        artifactURL: URL?,
        idlURL: URL?,
        gitCommit: String?,
        gitDirtyStatus: String?,
        upgradeAuthorityPubkey: String?
    ) throws -> WorkstationDeploymentReleaseRecord {
        try WorkstationDeploymentReleaseService.makeReleaseRecord(
            evidence: evidence,
            project: project,
            artifactURL: artifactURL,
            idlURL: idlURL,
            gitCommit: gitCommit,
            gitDirtyStatus: gitDirtyStatus,
            upgradeAuthorityPubkey: upgradeAuthorityPubkey
        )
    }
}
