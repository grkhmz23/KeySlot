import AppKit
import Foundation

extension DeveloperWorkstationStore {
    func prepareProgramCommandPreview() {
        let request = WorkstationProgramOperationRequest(
            operation: programOpsState.programOperation,
            cluster: selectionState.selectedCluster,
            project: selectionState.activeProject,
            toolchain: toolchainState.toolchainSnapshot,
            developerWallet: localnetState.developerWallet,
            artifactPath: programOpsState.artifactPath.isEmpty ? nil : programOpsState.artifactPath,
            programID: rpcState.programID.isEmpty ? nil : rpcState.programID,
            newAuthority: programOpsState.newAuthority.isEmpty ? nil : programOpsState.newAuthority,
            exactPhrase: programOpsState.destructivePhrase
        )
        do {
            let plan = try WorkstationProgramOpsRunner.preparePlan(request: request, keypairPath: "/tmp/[redacted-developer-authority].json")
            programOpsState.programCommandPlan = plan
            programOpsState.programCommandPreview = plan.redactedPreview
            let event: WorkstationActivityKind = switch programOpsState.programOperation {
            case .solanaProgramUpgrade:
                .programUpgradePreviewed
            case .solanaProgramClose:
                .programClosePreviewed
            case .solanaTransferUpgradeAuthority:
                .authorityTransferPreviewed
            case .solanaRevokeUpgradeAuthority:
                .authorityRevokePreviewed
            default:
                .commandPreviewPrepared
            }
            appendActivity(
                event,
                "Fixed command preview prepared.",
                details: ["operation": programOpsState.programOperation.rawValue, "cluster": selectionState.selectedCluster.rawValue]
            )
        } catch {
            programOpsState.programCommandPlan = nil
            programOpsState.programCommandPreview = error.localizedDescription
            if selectionState.selectedCluster == .mainnetBeta {
                appendActivity(.mainnetProgramOpBlocked, "Mainnet program operation blocked.", details: ["operation": programOpsState.programOperation.rawValue])
            }
            appendActivity(.commandBlocked, "Command preview blocked: \(error.localizedDescription)")
        }
    }

    func prepareLocalnetSmokePreflight() {
        let sampleProject = WorkstationSampleProject.anchorHelloWorld
        let sampleTrusted = selectionState.activeProject?.localPath == sampleProject.path && selectionState.activeProject?.trustStatus == .trusted
        localnetState.localnetSmokePreflight = WorkstationLocalnetSmokeRunner.preflight(
            sampleProjectPath: sampleProject.path,
            snapshot: toolchainState.toolchainSnapshot,
            developerWallet: localnetState.developerWallet,
            projectTrusted: sampleTrusted,
            startValidator: true
        )
        appendActivity(.sampleSmokeStarted, "Sample localnet smoke preflight prepared.")
    }

    func persistEvidence(_ evidence: WorkstationProgramOperationEvidence) {
        do {
            evidenceState.programEvidence = try dependencies.evidenceStore.append(evidence)
            evidenceState.evidenceStoreMessage = "Safe evidence stored at \(WorkstationProgramOperationEvidenceStore.defaultURL().lastPathComponent)."
            appendActivity(
                .programEvidenceStored,
                "Safe program-operation evidence stored.",
                details: ["cluster": evidence.cluster.rawValue, "operation": evidence.operation.rawValue]
            )
            createReleaseRecordIfSupported(from: evidence)
        } catch {
            evidenceState.evidenceStoreMessage = "Evidence store failed: \(AgentSafetyRedactor.redact(error.localizedDescription))"
            appendActivity(.commandBlocked, "Program evidence store failed.")
        }
    }

    func runDeploymentPreflight() {
        let decision = WorkstationProgramManager.evaluate(
            WorkstationProgramOperationRequest(
                operation: programOpsState.programOperation,
                cluster: selectionState.selectedCluster,
                project: selectionState.activeProject,
                toolchain: toolchainState.toolchainSnapshot,
                developerWallet: localnetState.developerWallet,
                artifactPath: programOpsState.artifactPath.isEmpty ? nil : programOpsState.artifactPath,
                programID: rpcState.programID.isEmpty ? nil : rpcState.programID,
                newAuthority: programOpsState.newAuthority.isEmpty ? nil : programOpsState.newAuthority,
                exactPhrase: programOpsState.destructivePhrase
            )
        )
        programOpsState.deploymentPreflightReport = dependencies.releaseService.preflight(
            WorkstationDeploymentPreflightInput(
                project: selectionState.activeProject,
                cluster: selectionState.selectedCluster,
                operation: programOpsState.programOperation,
                toolchain: toolchainState.toolchainSnapshot,
                developerWallet: localnetState.developerWallet,
                selectedProgramID: rpcState.programID.isEmpty ? nil : rpcState.programID,
                artifactPath: programOpsState.artifactPath.isEmpty ? nil : programOpsState.artifactPath,
                idlPath: selectedReleaseIDLPath(),
                idl: idlState.parsedIDL,
                projectBrain: projectState.currentProjectBrain,
                idlDriftReport: idlState.idlDriftReport,
                commandPreview: programOpsState.programCommandPlan,
                explicitApprovalReady: programOpsState.programCommandPlan != nil && decision.isAllowed,
                tempKeypairPolicyReady: programOpsState.programOperation == .anchorBuild || programOpsState.programOperation == .solanaProgramShow || localnetState.developerWallet.status == .ready,
                upgradeAuthorityPubkey: nil
            )
        )
        if programOpsState.deploymentPreflightReport.status == .blocked {
            appendActivity(.preflightFailed, "Deployment preflight blocked.", details: ["operation": programOpsState.programOperation.rawValue, "cluster": selectionState.selectedCluster.rawValue])
        } else {
            appendActivity(.commandPreviewPrepared, "Deployment preflight generated.", details: ["status": programOpsState.deploymentPreflightReport.status.rawValue])
        }
    }

    func createReleaseRecordFromLatestEvidence() {
        guard let latest = evidenceState.programEvidence.first else {
            programOpsState.releaseStoreMessage = "Release record requires stored program-operation evidence."
            appendActivity(.releaseFailed, "Release record creation blocked because no evidence exists.")
            return
        }
        createReleaseRecordIfSupported(from: latest)
    }

    func createReleaseRecordIfSupported(from evidence: WorkstationProgramOperationEvidence) {
        guard [.anchorDeploy, .solanaProgramDeploy, .solanaProgramUpgrade].contains(evidence.operation) else {
            return
        }
        do {
            let record = try dependencies.releaseService.makeReleaseRecord(
                evidence: evidence,
                project: selectionState.activeProject,
                artifactURL: existingReleaseURL(programOpsState.artifactPath.isEmpty ? evidence.artifactPath : programOpsState.artifactPath),
                idlURL: existingReleaseURL(selectedReleaseIDLPath() ?? evidence.idlPath),
                gitCommit: nil,
                gitDirtyStatus: nil,
                upgradeAuthorityPubkey: nil
            )
            programOpsState.releaseRecords = try dependencies.deploymentReleaseStore.append(record)
            programOpsState.releaseStoreMessage = "Release record stored with local hashes where files were available."
            appendActivity(.releaseCreated, "Deployment release record created.", details: ["cluster": record.cluster.rawValue, "operation": record.operation.rawValue])
        } catch {
            programOpsState.releaseStoreMessage = "Release record failed: \(AgentSafetyRedactor.redact(error.localizedDescription))"
            appendActivity(.releaseFailed, "Release record failed: \(error.localizedDescription)")
        }
    }

    func copyLatestReleaseJSON() {
        guard let latest = programOpsState.releaseRecords.first,
              let json = try? dependencies.deploymentReleaseStore.exportJSON(latest) else {
            programOpsState.releaseStoreMessage = "No release JSON is available to copy."
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(json, forType: .string)
        programOpsState.releaseStoreMessage = "Copied latest redacted release JSON."
        appendActivity(.localnetSmokeEvidenceViewed, "Copied redacted release JSON.")
    }

    func selectedReleaseIDLPath() -> String? {
        let driftPath = idlState.idlDriftTargetPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !driftPath.isEmpty {
            return driftPath
        }
        return projectState.currentProjectBrain?.idls.first?.relativePath
    }

    func existingReleaseURL(_ path: String?) -> URL? {
        guard let path = path?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty else {
            return nil
        }
        let url: URL
        if path.hasPrefix("/") {
            url = URL(fileURLWithPath: path)
        } else if let root = selectionState.activeProject?.localPath, !root.isEmpty {
            url = URL(fileURLWithPath: root, isDirectory: true).appendingPathComponent(path)
        } else {
            return nil
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return url
    }
}
