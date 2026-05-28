import AppKit
import Foundation

extension DeveloperWorkstationStore {
    func refreshTestDetection() {
        testSecurityState.isDetectingTests = true
        testSecurityState.testWorkbenchMessage = "Detecting test frameworks from project files only..."
        appendActivity(.testDetectionRefreshed, "Test Workbench detection started.")
        let project = selectionState.activeProject
        Task {
            let detection = await dependencies.testWorkbenchService.detectFrameworks(project: project)
            await MainActor.run {
                testSecurityState.testDetection = detection
                if let firstSupported = detection.frameworks.first(where: { $0.canPrepareCommand }) {
                    testSecurityState.selectedTestFramework = firstSupported.kind
                }
                testSecurityState.testWorkbenchMessage = "Detected \(detection.frameworks.count) framework entries and \(detection.testFiles.count) test files. No command was run."
                testSecurityState.isDetectingTests = false
                appendActivity(
                    .testDetectionRefreshed,
                    "Test framework detection refreshed.",
                    details: [
                        "frameworks": "\(detection.frameworks.count)",
                        "testFiles": "\(detection.testFiles.count)"
                    ]
                )
            }
        }
    }

    func prepareTestCommandPreview() {
        do {
            let preview = try dependencies.testWorkbenchService.prepareTestCommand(framework: testSecurityState.selectedTestFramework, project: selectionState.activeProject)
            testSecurityState.testCommandPreview = preview
            testSecurityState.testApprovalPhrase = ""
            testSecurityState.testWorkbenchMessage = "Fixed command preview prepared. Review it, then enter the exact approval phrase to run."
            appendActivity(.testCommandPrepared, "Test command preview prepared.", details: ["framework": testSecurityState.selectedTestFramework.rawValue])
        } catch {
            testSecurityState.testCommandPreview = nil
            testSecurityState.testWorkbenchMessage = AgentSafetyRedactor.redact(error.localizedDescription)
            appendActivity(.testRunBlocked, "Test command preview blocked: \(error.localizedDescription)")
        }
    }

    func runApprovedTest() {
        guard testSecurityState.testApprovalPhrase == TestWorkbenchService.approvalPhrase else {
            testSecurityState.testWorkbenchMessage = "Exact approval phrase is required before running tests."
            appendActivity(.testRunBlocked, "Test run blocked by missing approval phrase.")
            return
        }
        guard let commandId = testSecurityState.testCommandPreview?.id else {
            testSecurityState.testWorkbenchMessage = "Prepare a fixed command preview before running tests."
            appendActivity(.testRunBlocked, "Test run blocked because no preview exists.")
            return
        }
        testSecurityState.isRunningTests = true
        testSecurityState.testWorkbenchMessage = "Running approved fixed test command with bounded redacted output..."
        appendActivity(.testRunStarted, "Approved Test Workbench command started.", details: ["framework": testSecurityState.selectedTestFramework.rawValue])
        Task {
            do {
                let evidence = try await dependencies.testWorkbenchService.runApprovedTest(commandId: commandId)
                await MainActor.run {
                    testSecurityState.isRunningTests = false
                    testSecurityState.testCommandPreview = nil
                    testSecurityState.testApprovalPhrase = ""
                    testSecurityState.testWorkbenchMessage = "Test run \(evidence.status.title.lowercased()). Evidence stored with redacted bounded logs."
                    do {
                        testSecurityState.testRunHistory = try dependencies.testRunEvidenceStore.append(evidence)
                        appendActivity(.testEvidenceStored, "Test run evidence stored.", details: ["status": evidence.status.rawValue])
                    } catch {
                        appendActivity(.commandBlocked, "Test evidence store failed: \(error.localizedDescription)")
                    }
                    if !evidence.computeMeasurements.isEmpty {
                        do {
                            let payload = try dependencies.computeRegressionStore.append(measurements: evidence.computeMeasurements)
                            testSecurityState.computeMeasurements = payload.measurements
                            testSecurityState.computeBaselines = payload.baselines
                            appendActivity(.computeMeasurementStored, "Compute measurements stored from test output.", details: ["count": "\(evidence.computeMeasurements.count)"])
                        } catch {
                            appendActivity(.commandBlocked, "Compute measurement store failed: \(error.localizedDescription)")
                        }
                    }
                    appendActivity(evidence.status == .succeeded ? .testRunSucceeded : .testRunFailed, "Approved test run completed.", details: ["status": evidence.status.rawValue])
                }
            } catch {
                await MainActor.run {
                    testSecurityState.isRunningTests = false
                    testSecurityState.testWorkbenchMessage = AgentSafetyRedactor.redact(error.localizedDescription)
                    appendActivity(.testRunFailed, "Approved test run failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func createTestDraft(_ suggestion: WorkstationMissingTestSuggestion) {
        do {
            let detectedFramework = testSecurityState.testDetection.frameworks.first { $0.kind == testSecurityState.selectedTestFramework }
            let framework = detectedFramework?.canPrepareCommand == true ? testSecurityState.selectedTestFramework : nil
            let draft = try dependencies.testWorkbenchService.generateDraft(
                for: suggestion,
                project: selectionState.activeProject,
                framework: framework
            )
            testSecurityState.generatedTestDrafts.insert(draft, at: 0)
            testSecurityState.generatedTestDrafts = Array(testSecurityState.generatedTestDrafts.prefix(20))
            testSecurityState.testDraftMessage = "Created draft at \(draft.safeRelativePath). It was not added to the project and will not run automatically."
            appendActivity(.testDraftCreated, "Safe test draft created.", details: ["mode": draft.mode.rawValue])
        } catch {
            testSecurityState.testDraftMessage = AgentSafetyRedactor.redact(error.localizedDescription)
            appendActivity(.commandBlocked, "Test draft creation failed: \(error.localizedDescription)")
        }
    }

    func storeComputeFromTransactionDebugger() {
        guard let report = rpcState.transactionDebugReport else {
            testSecurityState.computeRegressionMessage = "No Transaction Debugger report is loaded."
            return
        }
        let measurements = ComputeRegressionService.measurements(
            fromLogs: report.logs,
            projectID: selectionState.activeProject?.id.uuidString,
            instructionName: testSecurityState.computeInstructionName,
            source: .transactionDebugger,
            signature: report.signature,
            evidenceId: report.evidenceId.uuidString
        )
        storeComputeMeasurements(measurements, sourceDescription: "Transaction Debugger")
    }

    func storeComputeFromLatestTest() {
        guard let run = testSecurityState.testRunHistory.first else {
            testSecurityState.computeRegressionMessage = "No Test Workbench run output is stored."
            return
        }
        let measurements = ComputeRegressionService.measurements(
            fromLogs: [run.stdoutSummary, run.stderrSummary],
            projectID: run.projectID?.uuidString,
            instructionName: testSecurityState.computeInstructionName,
            source: .testOutput,
            evidenceId: run.id.uuidString
        )
        storeComputeMeasurements(measurements, sourceDescription: "latest test output")
    }

    func storeComputeMeasurements(_ measurements: [WorkstationComputeMeasurement], sourceDescription: String) {
        guard !measurements.isEmpty else {
            testSecurityState.computeRegressionMessage = "No compute-unit lines were found in \(sourceDescription) logs."
            return
        }
        do {
            let payload = try dependencies.computeRegressionStore.append(measurements: measurements)
            testSecurityState.computeMeasurements = payload.measurements
            testSecurityState.computeBaselines = payload.baselines
            testSecurityState.computeRegressionMessage = "Stored \(measurements.count) compute measurement(s) from \(sourceDescription)."
            appendActivity(.computeMeasurementStored, "Compute measurements stored.", details: ["source": sourceDescription, "count": "\(measurements.count)"])
        } catch {
            testSecurityState.computeRegressionMessage = AgentSafetyRedactor.redact(error.localizedDescription)
            appendActivity(.commandBlocked, "Compute measurement store failed: \(error.localizedDescription)")
        }
    }

    func selectComputeBaseline(_ measurement: WorkstationComputeMeasurement) {
        do {
            let baseline = ComputeRegressionService.selectBaseline(from: measurement)
            let payload = try dependencies.computeRegressionStore.selectBaseline(baseline)
            testSecurityState.computeMeasurements = payload.measurements
            testSecurityState.computeBaselines = payload.baselines
            testSecurityState.computeRegressionMessage = "Selected \(measurement.computeUnits) CU as baseline for \(measurement.instructionName)."
            appendActivity(.computeBaselineSelected, "Compute baseline selected.", details: ["instruction": measurement.instructionName])
        } catch {
            testSecurityState.computeRegressionMessage = AgentSafetyRedactor.redact(error.localizedDescription)
            appendActivity(.commandBlocked, "Compute baseline selection failed: \(error.localizedDescription)")
        }
    }

    func runSecurityScan() {
        guard let project = selectionState.activeProject else {
            testSecurityState.securityScanMessage = "Import a folder project before running Security Scanner."
            appendActivity(.securityScanFailed, "Security scan blocked because no project is active.")
            return
        }
        testSecurityState.isSecurityScanning = true
        testSecurityState.securityScanMessage = "Scanning source files read-only..."
        appendActivity(.securityScanStarted, "Security scan started.", details: ["project": project.displayName])

        Task {
            do {
                let report = try dependencies.securityScanner.scan(
                    project: project,
                    projectBrain: projectState.currentProjectBrain?.projectId == project.id.uuidString ? projectState.currentProjectBrain : nil,
                    idl: idlState.parsedIDL,
                    releaseRecords: programOpsState.releaseRecords
                )
                await MainActor.run {
                    testSecurityState.securityScanReport = report
                    testSecurityState.securityScanMessage = report.summary
                    testSecurityState.isSecurityScanning = false
                    appendActivity(
                        .securityScanCompleted,
                        "Security scan completed.",
                        details: [
                            "project": report.projectName,
                            "findings": "\(report.findings.count)",
                            "files": "\(report.scannedFileCount)"
                        ]
                    )
                    do {
                        testSecurityState.securityScanReports = try dependencies.securityScanStore.append(report)
                        appendActivity(.securityScanEvidenceStored, "Security scan report stored as redacted JSON.")
                    } catch {
                        appendActivity(.commandBlocked, "Security scan evidence store failed: \(error.localizedDescription)")
                    }
                }
            } catch {
                await MainActor.run {
                    testSecurityState.securityScanMessage = AgentSafetyRedactor.redact(error.localizedDescription)
                    testSecurityState.isSecurityScanning = false
                    appendActivity(.securityScanFailed, "Security scan failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func dismissSecurityFinding(_ id: String) {
        guard var report = testSecurityState.securityScanReport else { return }
        let reason = testSecurityState.securityDismissalReason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reason.isEmpty else { return }
        let findings = report.findings.map { finding in
            finding.id == id ? finding.dismissed(reason: reason) : finding
        }
        report = SecurityScanReport(
            id: report.id,
            projectId: report.projectId,
            projectName: report.projectName,
            projectRootDisplay: report.projectRootDisplay,
            generatedAt: report.generatedAt,
            readOnly: report.readOnly,
            scannedFileCount: report.scannedFileCount,
            sourceLineCount: report.sourceLineCount,
            projectBrainId: report.projectBrainId,
            findings: findings,
            unsupportedFindings: report.unsupportedFindings,
            summary: report.summary
        )
        testSecurityState.securityScanReport = report
        testSecurityState.securityDismissalReason = ""
        do {
            var reports = testSecurityState.securityScanReports.filter { $0.id != report.id }
            reports.insert(report, at: 0)
            testSecurityState.securityScanReports = reports
            try dependencies.securityScanStore.save(reports)
            appendActivity(.securityFindingDismissed, "Security finding dismissed.", details: ["finding": id])
        } catch {
            appendActivity(.commandBlocked, "Security scan dismissal store failed: \(error.localizedDescription)")
        }
    }

    func copySecurityScanJSON() {
        guard let report = testSecurityState.securityScanReport,
              let json = try? dependencies.securityScanStore.exportJSON(report) else {
            testSecurityState.securityScanMessage = "No security scan JSON is available to copy."
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(json, forType: .string)
        testSecurityState.securityScanMessage = "Copied redacted Security Scanner report."
        appendActivity(.securityScanReviewed, "Copied redacted Security Scanner report JSON.")
    }

    func clearTestPreview() {
        testSecurityState.testCommandPreview = nil
        testSecurityState.testApprovalPhrase = ""
    }
}
