import AppKit
import Foundation

extension DeveloperWorkstationStore {
    func inspectFrontend() {
        do {
            let report = try dependencies.frontendService.inspect(
                project: selectionState.activeProject,
                projectBrain: projectState.currentProjectBrain,
                idl: idlState.parsedIDL
            )
            agentFrontendState.frontendReport = report
            agentFrontendState.frontendMessage = report.summary
            if agentFrontendState.frontendSelectedInstruction.isEmpty, let first = report.draftableInstructions.first {
                agentFrontendState.frontendSelectedInstruction = first
            }
            appendActivity(
                .frontendInspected,
                "Frontend Assistant inspected bounded project files.",
                details: ["files": "\(report.scannedFileCount)", "status": report.status.rawValue]
            )
        } catch {
            agentFrontendState.frontendMessage = AgentSafetyRedactor.redact(error.localizedDescription)
            appendActivity(.commandBlocked, "Frontend Assistant inspect failed: \(error.localizedDescription)")
        }
    }

    func prepareFrontendDrafts() {
        do {
            let drafts = try dependencies.frontendService.prepareDrafts(
                kind: agentFrontendState.frontendDraftKind,
                instructionName: agentFrontendState.frontendSelectedInstruction.isEmpty ? nil : agentFrontendState.frontendSelectedInstruction,
                project: selectionState.activeProject,
                projectBrain: projectState.currentProjectBrain,
                idl: idlState.parsedIDL,
                report: agentFrontendState.frontendReport
            )
            agentFrontendState.frontendDrafts = drafts
            agentFrontendState.frontendMessage = "Prepared \(drafts.count) draft file preview(s). Nothing was written."
            appendActivity(
                .frontendDraftPreviewed,
                "Frontend Assistant draft preview generated.",
                details: ["kind": agentFrontendState.frontendDraftKind.rawValue, "files": "\(drafts.count)"]
            )
        } catch {
            agentFrontendState.frontendMessage = AgentSafetyRedactor.redact(error.localizedDescription)
            appendActivity(.frontendDraftWriteBlocked, "Frontend draft preview blocked: \(error.localizedDescription)")
        }
    }

    func writeFrontendDrafts() {
        do {
            let evidence = try dependencies.frontendService.writeDrafts(
                agentFrontendState.frontendDrafts,
                project: selectionState.activeProject,
                approvalPhrase: agentFrontendState.frontendWriteApprovalPhrase,
                selectedInstruction: agentFrontendState.frontendSelectedInstruction
            )
            agentFrontendState.frontendEvidence = try dependencies.frontendEvidenceStore.append(evidence)
            agentFrontendState.frontendMessage = evidence.summary
            let wrote = evidence.files.filter { $0.status == .written }.count
            appendActivity(
                wrote > 0 ? .frontendDraftWritten : .frontendDraftWriteBlocked,
                wrote > 0 ? "Frontend Assistant wrote approved draft files." : "Frontend Assistant did not overwrite existing draft files.",
                details: ["files": "\(wrote)"]
            )
            appendActivity(.frontendEvidenceStored, "Frontend Assistant generation evidence stored as redacted JSON.")
        } catch {
            agentFrontendState.frontendMessage = AgentSafetyRedactor.redact(error.localizedDescription)
            appendActivity(.frontendDraftWriteBlocked, "Frontend draft write blocked: \(error.localizedDescription)")
        }
    }

    func copyFrontendDrafts() {
        guard !agentFrontendState.frontendDrafts.isEmpty else {
            agentFrontendState.frontendMessage = "No generated draft preview is available to copy."
            return
        }
        let text = agentFrontendState.frontendDrafts.map { draft in
            """
            // \(draft.relativePath)
            \(draft.content)
            """
        }.joined(separator: "\n\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        agentFrontendState.frontendMessage = "Copied generated draft preview."
        appendActivity(.frontendDraftPreviewed, "Frontend Assistant draft preview copied.")
    }

    func revealGeneratedFrontendFile(_ relativePath: String) {
        guard let project = selectionState.activeProject else {
            agentFrontendState.frontendMessage = "No active project is available."
            return
        }
        let root = URL(fileURLWithPath: project.localPath, isDirectory: true).standardizedFileURL
        let cleaned = DeveloperProjectBrainPath.cleanRelativePath(relativePath)
        let url = root.appendingPathComponent(cleaned).standardizedFileURL
        guard url.path.hasPrefix(root.path + "/"),
              cleaned.hasPrefix("keyslot/frontend-assistant/"),
              FileManager.default.fileExists(atPath: url.path) else {
            agentFrontendState.frontendMessage = "Generated file path is unavailable or outside the approved output folder."
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func runDeveloperAgentTool() {
        agentFrontendState.isDeveloperAgentCallingTool = true
        agentFrontendState.developerAgentMessage = "Running typed Developer Agent tool..."
        let input = developerAgentInput()
        let context = developerAgentContext()
        let toolID = agentFrontendState.developerAgentToolID
        let mode = agentFrontendState.developerAgentMode

        Task {
            let record = await DeveloperWorkstationAgentService.execute(
                toolID: toolID,
                mode: mode,
                input: input,
                context: context
            )
            await MainActor.run {
                agentFrontendState.developerAgentHistory.insert(record, at: 0)
                agentFrontendState.developerAgentHistory = Array(agentFrontendState.developerAgentHistory.prefix(120))
                agentFrontendState.developerAgentMessage = record.outputSummary
                agentFrontendState.isDeveloperAgentCallingTool = false
                switch record.status {
                case .blocked:
                    appendActivity(.workstationAgentToolBlocked, record.outputSummary, details: ["tool": record.toolID])
                case .approvalRequired:
                    appendActivity(.workstationAgentApprovalRequested, record.outputSummary, details: ["tool": record.toolID])
                case .succeeded, .delegated, .unavailable:
                    appendActivity(.workstationAgentToolCalled, record.outputSummary, details: ["tool": record.toolID, "status": record.status.rawValue])
                }
                do {
                    agentFrontendState.developerAgentHistory = try dependencies.developerAgentHistoryStore.append(record)
                    appendActivity(.workstationAgentEvidenceStored, "Developer Agent tool history stored as redacted JSON.", details: ["tool": record.toolID])
                } catch {
                    agentFrontendState.developerAgentMessage = "Tool call completed, but redacted history storage failed: \(error.localizedDescription)"
                }
            }
        }
    }

    func developerAgentInput() -> DeveloperAgentToolInput {
        let seed = agentFrontendState.developerAgentSeed.trimmingCharacters(in: .whitespacesAndNewlines)
        let seedInputs = seed.isEmpty ? [] : [WorkstationPDASeedInput(kind: .utf8String, value: seed)]
        let prompt = agentFrontendState.developerAgentPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let promptLines = prompt
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        return DeveloperAgentToolInput(
            prompt: prompt.ifEmptyOptional,
            signature: agentFrontendState.developerAgentSignature.trimmingCharacters(in: .whitespacesAndNewlines).ifEmptyOptional,
            programID: agentFrontendState.developerAgentProgramID.trimmingCharacters(in: .whitespacesAndNewlines).ifEmptyOptional,
            expectedAddress: nil,
            accountAddress: agentFrontendState.developerAgentAccountAddress.trimmingCharacters(in: .whitespacesAndNewlines).ifEmptyOptional,
            accountDataBase64: agentFrontendState.developerAgentAccountDataBase64.trimmingCharacters(in: .whitespacesAndNewlines).ifEmptyOptional,
            idlAccountName: agentFrontendState.developerAgentIDLAccountName.trimmingCharacters(in: .whitespacesAndNewlines).ifEmptyOptional,
            seedInputs: seedInputs,
            logs: promptLines,
            rpcMethod: agentFrontendState.developerAgentRPCMethod.rawValue,
            encodedTransaction: rpcState.encodedTransaction.trimmingCharacters(in: .whitespacesAndNewlines).ifEmptyOptional,
            operation: agentFrontendState.developerAgentOperation,
            artifactPath: programOpsState.artifactPath.trimmingCharacters(in: .whitespacesAndNewlines).ifEmptyOptional,
            newAuthority: programOpsState.newAuthority.trimmingCharacters(in: .whitespacesAndNewlines).ifEmptyOptional,
            testFramework: testSecurityState.selectedTestFramework,
            instructionName: agentFrontendState.developerAgentInstructionName.trimmingCharacters(in: .whitespacesAndNewlines).ifEmptyOptional,
            frontendDraftKind: agentFrontendState.developerAgentDraftKind,
            approvalPhrase: agentFrontendState.developerAgentApprovalPhrase.trimmingCharacters(in: .whitespacesAndNewlines).ifEmptyOptional
        )
    }

    func developerAgentContext() -> DeveloperAgentToolContext {
        DeveloperAgentToolContext(
            project: selectionState.activeProject,
            cluster: selectionState.selectedCluster,
            idl: idlState.parsedIDL,
            projectBrain: projectState.currentProjectBrain,
            transactionDebugReport: rpcState.transactionDebugReport,
            localValidatorStatus: localnetState.localValidatorStatus,
            toolchain: toolchainState.toolchainSnapshot,
            programEvidence: evidenceState.programEvidence,
            releaseRecords: programOpsState.releaseRecords,
            securityReport: testSecurityState.securityScanReport,
            frontendReport: agentFrontendState.frontendReport,
            developerWallet: localnetState.developerWallet
        )
    }

    // MARK: - Chat / Proposal

    func submitDeveloperAgentChat() {
        let input = agentFrontendState.developerAgentChatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard input.isEmpty == false else { return }
        agentFrontendState.developerAgentChatInput = ""
        agentFrontendState.developerAgentChatMessages.append(AgentChatMessage(role: .user, text: input))

        if let display = WorkstationAgentIntentMapper.map(input) {
            agentFrontendState.developerAgentActiveProposal = display
            let assistantText: String
            if display.blockedReason != nil {
                assistantText = "Blocked: \(display.blockedReason!)"
                appendActivity(.workstationAgentToolBlocked, display.blockedReason!)
            } else {
                assistantText = "I created a proposal for '\(display.title)'. Review the card and approve or reject."
                appendActivity(.workstationAgentToolCalled, "Chat proposal created: \(display.title)")
            }
            agentFrontendState.developerAgentChatMessages.append(AgentChatMessage(role: .assistant, text: assistantText))
        } else {
            agentFrontendState.developerAgentChatMessages.append(AgentChatMessage(
                role: .assistant,
                text: "I didn't recognize that request. Try 'scan project', 'debug transaction', 'pda', 'idl drift', 'run tests', or 'build'."
            ))
        }
    }

    func rejectDeveloperAgentProposal() {
        guard let proposal = agentFrontendState.developerAgentActiveProposal else { return }
        agentFrontendState.developerAgentActiveProposal = nil
        agentFrontendState.developerAgentChatMessages.append(AgentChatMessage(
            role: .system,
            text: "Proposal '\(proposal.title)' rejected. Nothing was executed."
        ))
        appendActivity(.workstationAgentToolBlocked, "Proposal rejected by user: \(proposal.title)")
    }

    func approveDeveloperAgentProposal() {
        guard let display = agentFrontendState.developerAgentActiveProposal else { return }
        agentFrontendState.developerAgentActiveProposal = nil

        // Map proposal title to tool ID
        let toolID: String
        let section: DeveloperWorkstationSection?
        switch display.title {
        case "Scan Project Brain":
            toolID = "project.scanBrain"
            section = .projectBrain
        case "Debug Transaction":
            toolID = "transaction.debug"
            section = .transactionDebugger
        case "Derive PDA":
            toolID = "pda.derive"
            section = .pdaExplorer
        case "Check IDL Drift":
            toolID = "idl.diff"
            section = .idlDrift
        case "Decode Account":
            toolID = "account.decode"
            section = .accountDecoder
        case "Run Tests":
            toolID = "test.detect"
            section = .testWorkbench
        case "Build / Deploy":
            toolID = "program.preflight"
            section = .programManager
        default:
            toolID = ""
            section = nil
        }

        guard !toolID.isEmpty else {
            agentFrontendState.developerAgentChatMessages.append(AgentChatMessage(
                role: .system,
                text: "Proposal '\(display.title)' could not be matched to a workstation tool."
            ))
            return
        }

        agentFrontendState.developerAgentToolID = toolID

        // Apply prefilled inputs from chat parsing
        if let signature = display.prefill["signature"] {
            rpcState.transactionDebugSignature = signature
        }
        if let address = display.prefill["address"] {
            agentFrontendState.developerAgentAccountAddress = address
        }
        if let seeds = display.prefill["seeds"] {
            agentFrontendState.developerAgentSeed = seeds
        }

        // For read-only tools, try to execute directly
        let readOnlyTools = [
            "project.scanBrain", "project.getBrain", "idl.list", "idl.diff",
            "account.decode", "pda.derive", "transaction.debug", "logs.parse",
            "rpc.safeRead", "localnet.status", "test.detect", "compute.record",
            "program.preflight", "security.scan", "frontend.inspect", "frontend.generateDraft"
        ]

        if readOnlyTools.contains(toolID) {
            agentFrontendState.developerAgentChatMessages.append(AgentChatMessage(
                role: .system,
                text: "Running '\(display.title)' through existing workstation gates…"
            ))
            runDeveloperAgentTool()
        } else {
            agentFrontendState.developerAgentChatMessages.append(AgentChatMessage(
                role: .system,
                text: "Proposal '\(display.title)' approved. Go to the \(section?.title ?? "Workstation") section to review and approve through the existing safe flow."
            ))
            if let section = section {
                agentFrontendState.pendingWorkstationSection = section
            }
        }
        appendActivity(.workstationAgentToolCalled, "Proposal approved by user: \(display.title)")
    }
}
