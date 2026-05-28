import Foundation

extension DeveloperWorkstationStore {
    func deriveManualPDA() {
        let result = dependencies.pdaService.derive(
            WorkstationPDADerivationRequest(
                programID: rpcState.programID,
                seeds: rpcState.pdaSeedInputs,
                expectedAddress: rpcState.accountAddress.isEmpty ? nil : rpcState.accountAddress
            )
        )
        rpcState.manualPDAResult = result
        rpcState.pdaAccountCheck = WorkstationPDAAccountCheck(
            status: .notRun,
            address: result.derivedAddress,
            ownerProgram: nil,
            ownerLabel: nil,
            lamports: nil,
            executable: nil,
            dataLength: nil,
            decodedAccountType: nil,
            message: result.derivedAddress == nil ? "Derive a PDA before checking account existence." : "PDA derived. Account existence check has not run."
        )
        appendActivity(.pdaDerived, "Manual PDA derivation reviewed.", details: ["status": result.status.rawValue])
    }

    func checkDerivedPDAAccount() {
        guard let address = rpcState.manualPDAResult?.derivedAddress else {
            return
        }
        rpcState.isCheckingPDAAccount = true
        Task {
            let check = await dependencies.pdaService.checkAccount(address: address, cluster: selectionState.selectedCluster, idl: idlState.parsedIDL)
            await MainActor.run {
                rpcState.pdaAccountCheck = check
                rpcState.isCheckingPDAAccount = false
                appendActivity(.pdaAccountChecked, "PDA account existence checked with read-only getAccountInfo.", details: ["cluster": selectionState.selectedCluster.rawValue, "status": check.status.rawValue])
            }
        }
    }

    func compareIDLDrift() {
        guard let parsedIDL = idlState.parsedIDL,
              let activeProject = selectionState.activeProject,
              !idlState.idlDriftTargetPath.isEmpty else {
            return
        }
        do {
            let url = try safeProjectFileURL(project: activeProject, relativePath: idlState.idlDriftTargetPath)
            let data = try Data(contentsOf: url)
            let target = try WorkstationIDLParser.parse(data: data)
            let report = dependencies.idlDriftService.compare(
                source: parsedIDL,
                target: target,
                sourceLabel: "Loaded IDL",
                targetLabel: idlState.idlDriftTargetPath
            )
            idlState.idlDriftReport = report
            appendActivity(.idlDriftCompared, "IDL drift comparison completed.", details: ["findings": "\(report.findings.count)"])
        } catch {
            idlState.idlDriftReport = WorkstationIDLDriftReport(
                sourceName: parsedIDL.name,
                targetName: idlState.idlDriftTargetPath,
                generatedAt: Date(),
                findings: [
                    WorkstationIDLDriftFinding(
                        id: "compare-unavailable",
                        severity: .warning,
                        source: "Loaded IDL",
                        target: DeveloperProjectBrainPath.cleanRelativePath(idlState.idlDriftTargetPath),
                        category: "Unavailable",
                        detail: AgentSafetyRedactor.redact(error.localizedDescription),
                        suggestedAction: "Choose a safe project IDL path from Project Brain and retry."
                    )
                ]
            )
            appendActivity(.commandBlocked, "IDL drift comparison failed: \(error.localizedDescription)")
        }
    }

    func runTransactionDebug() {
        let signature = rpcState.transactionDebugSignature.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !signature.isEmpty else {
            rpcState.transactionDebugStatus = .missing
            rpcState.transactionDebugMessage = "Enter a public Solana transaction signature first."
            return
        }
        rpcState.isTransactionDebugging = true
        rpcState.transactionDebugStatus = .unavailable
        rpcState.transactionDebugMessage = "Fetching transaction with read-only getTransaction..."
        appendActivity(.transactionDebugFetchStarted, "Transaction Debugger fetch started.", details: ["cluster": selectionState.selectedCluster.rawValue])
        let selectedIDL: WorkstationIDL?
        do {
            selectedIDL = try selectedTransactionDebugIDL()
        } catch {
            rpcState.transactionDebugStatus = .error
            rpcState.transactionDebugMessage = AgentSafetyRedactor.redact(error.localizedDescription)
            rpcState.isTransactionDebugging = false
            appendActivity(.transactionDebugFetchFailed, "Transaction Debugger IDL load failed: \(error.localizedDescription)")
            return
        }
        let cluster = selectionState.selectedCluster
        let projectId = selectionState.activeProject?.id.uuidString
        let idlSelection = rpcState.transactionDebugIDLSelection
        let brain = projectState.currentProjectBrain

        Task {
            do {
                let report = try await dependencies.transactionDebugService.debugTransaction(
                    signature: signature,
                    cluster: cluster,
                    projectId: projectId,
                    idlId: idlSelection,
                    projectBrain: brain,
                    idl: selectedIDL
                )
                await MainActor.run {
                    rpcState.transactionDebugReport = report
                    rpcState.transactionDebugStatus = report.status == .unsupported ? .error : .ready
                    rpcState.transactionDebugMessage = "\(report.status.title): \(report.likelyRootCause)"
                    rpcState.isTransactionDebugging = false
                    appendActivity(
                        report.status == .unsupported ? .transactionDebugFetchFailed : .transactionDebugFetchSucceeded,
                        "Transaction Debugger fetch completed.",
                        details: [
                            "status": report.status.rawValue,
                            "cluster": report.cluster.rawValue
                        ]
                    )
                    do {
                        rpcState.transactionDebugEvidence = try dependencies.transactionDebugEvidenceStore.append(report)
                        appendActivity(.transactionDebugEvidenceStored, "Transaction debug evidence stored as redacted bounded JSON.")
                    } catch {
                        appendActivity(.commandBlocked, "Transaction debug evidence store failed: \(error.localizedDescription)")
                    }
                }
            } catch {
                await MainActor.run {
                    rpcState.transactionDebugStatus = .error
                    rpcState.transactionDebugMessage = AgentSafetyRedactor.redact(error.localizedDescription)
                    rpcState.isTransactionDebugging = false
                    appendActivity(.transactionDebugFetchFailed, "Transaction Debugger fetch failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func fetchTransactionDebugAccountDetails() {
        guard let report = rpcState.transactionDebugReport else {
            return
        }
        rpcState.isFetchingTransactionAccountDetails = true
        rpcState.transactionDebugMessage = "Fetching bounded read-only account details..."
        Task {
            do {
                let updated = try await dependencies.transactionDebugService.fetchAccountDetails(for: report)
                await MainActor.run {
                    rpcState.transactionDebugReport = updated
                    rpcState.transactionDebugMessage = "Fetched account details for up to 20 transaction accounts."
                    rpcState.isFetchingTransactionAccountDetails = false
                    appendActivity(.transactionDebugAccountDetailsFetched, "Transaction Debugger fetched bounded account details.", details: ["cluster": updated.cluster.rawValue])
                    do {
                        rpcState.transactionDebugEvidence = try dependencies.transactionDebugEvidenceStore.append(updated)
                        appendActivity(.transactionDebugEvidenceStored, "Transaction debug evidence updated with bounded account details.")
                    } catch {
                        appendActivity(.commandBlocked, "Transaction debug evidence update failed: \(error.localizedDescription)")
                    }
                }
            } catch {
                await MainActor.run {
                    rpcState.transactionDebugMessage = AgentSafetyRedactor.redact(error.localizedDescription)
                    rpcState.isFetchingTransactionAccountDetails = false
                    appendActivity(.transactionDebugFetchFailed, "Transaction account detail fetch failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func selectedTransactionDebugIDL() throws -> WorkstationIDL? {
        if rpcState.transactionDebugIDLSelection == "__none" {
            return nil
        }
        if rpcState.transactionDebugIDLSelection == "__loaded" {
            return idlState.parsedIDL
        }
        guard let project = selectionState.activeProject else {
            return idlState.parsedIDL
        }
        let relativePath = DeveloperProjectBrainPath.cleanRelativePath(rpcState.transactionDebugIDLSelection)
        let url = try safeProjectFileURL(project: project, relativePath: relativePath)
        let text = try String(contentsOf: url, encoding: .utf8)
        return try WorkstationIDLParser.parse(string: text)
    }

    func parseIDL() {
        do {
            idlState.parsedIDL = try WorkstationIDLParser.parse(string: idlState.idlText)
            appendActivity(.idlLoaded, "IDL loaded.")
        } catch {
            appendActivity(.commandBlocked, "IDL parse failed: \(error.localizedDescription)")
        }
    }
}
