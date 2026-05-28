import AppKit
import Foundation

extension DeveloperWorkstationStore {
    func scanProjectBrain() {
        guard let project = selectionState.activeProject else {
            projectState.projectBrainStatus = .missing
            projectState.projectBrainMessage = "Import a folder project before scanning Project Brain."
            appendActivity(.projectBrainScanFailed, "Project Brain scan blocked because no project is active.")
            return
        }
        projectState.isProjectBrainScanning = true
        projectState.projectBrainStatus = .unavailable
        projectState.projectBrainMessage = "Scanning project files read-only..."
        appendActivity(.projectBrainScanStarted, "Project Brain scan started.", details: ["project": project.displayName])

        Task {
            do {
                let brain = try await dependencies.projectBrainScanner.scan(project: project)
                await MainActor.run {
                    projectState.currentProjectBrain = brain
                    projectState.projectBrainStatus = .ready
                    projectState.projectBrainMessage = "Project Brain scanned \(brain.detectedFiles.count) file(s), \(brain.programs.count) program(s), and \(brain.warnings.count) warning(s)."
                    projectState.isProjectBrainScanning = false
                    appendActivity(
                        .projectBrainScanned,
                        "Project Brain scan completed.",
                        details: [
                            "project": brain.projectName,
                            "programs": "\(brain.programs.count)",
                            "warnings": "\(brain.warnings.count)"
                        ]
                    )
                    do {
                        projectState.projectBrainReports = try dependencies.projectBrainStore.append(brain)
                        appendActivity(.projectBrainEvidenceStored, "Project Brain report stored as redacted JSON.")
                    } catch {
                        appendActivity(.commandBlocked, "Project Brain evidence store failed: \(error.localizedDescription)")
                    }
                }
            } catch {
                await MainActor.run {
                    projectState.projectBrainStatus = .error
                    projectState.projectBrainMessage = AgentSafetyRedactor.redact(error.localizedDescription)
                    projectState.isProjectBrainScanning = false
                    appendActivity(.projectBrainScanFailed, "Project Brain scan failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func openProjectBrainIDL(_ idl: IDLBrain) {
        guard let project = selectionState.activeProject else {
            appendActivity(.commandBlocked, "IDL handoff blocked because no project is active.")
            return
        }
        let relativePath = DeveloperProjectBrainPath.cleanRelativePath(idl.relativePath)
        let root = URL(fileURLWithPath: project.localPath, isDirectory: true).standardizedFileURL
        let url = root.appendingPathComponent(relativePath).standardizedFileURL
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard url.path.hasPrefix(rootPath),
              let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey]),
              values.isRegularFile == true,
              values.isSymbolicLink != true,
              (values.fileSize ?? 0) <= 512 * 1024,
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            appendActivity(.commandBlocked, "IDL Browser handoff unavailable for \(relativePath).")
            selectionState.selectedSection = .idlBrowser
            return
        }
        idlState.idlText = text
        parseIDL()
        selectionState.selectedSection = .idlBrowser
    }

    func inspectFolder() {
        do {
            let project = try WorkstationProjectImporter().inspectFolder(URL(fileURLWithPath: projectState.projectPathInput))
            selectionState.activeProject = project
            projectState.currentProjectBrain = projectState.projectBrainReports.first { $0.projectId == project.id.uuidString }
            projectState.projectBrainStatus = projectState.currentProjectBrain == nil ? .missing : .ready
            projectState.projectBrainMessage = projectState.currentProjectBrain == nil ? "Project imported. Open Project Brain and rescan to generate a fresh read-only graph." : "Loaded stored Project Brain report for the selected project."
            appendActivity(.projectImported, "Project imported from folder.", details: ["source": "folder"])
        } catch {
            appendActivity(.commandBlocked, "Folder import failed: \(error.localizedDescription)")
        }
    }

    func inspectZip() {
        do {
            let project = try WorkstationProjectImporter().inspectZip(URL(fileURLWithPath: projectState.zipPathInput))
            selectionState.activeProject = project
            projectState.currentProjectBrain = nil
            projectState.projectBrainStatus = .unavailable
            projectState.projectBrainMessage = "Zip imports are metadata-only until a reviewed extraction flow provides a local folder."
            appendActivity(.projectImported, "Project zip metadata inspected.", details: ["source": "zip"])
        } catch {
            appendActivity(.commandBlocked, "Zip import failed: \(error.localizedDescription)")
        }
    }

    func prepareGitClone() {
        do {
            let workspace = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first!
                .appendingPathComponent("KeySlot/Workspaces", isDirectory: true)
            let (project, _) = try WorkstationProjectImporter().prepareGitImport(urlString: projectState.gitURLInput, workspaceRoot: workspace)
            selectionState.activeProject = project
            projectState.currentProjectBrain = nil
            projectState.projectBrainStatus = .missing
            projectState.projectBrainMessage = "Git clone is prepared but not scanned until a local folder exists."
            appendActivity(.projectImported, "HTTPS Git clone prepared with fixed args.", details: ["source": "git"])
        } catch {
            appendActivity(.commandBlocked, "Git import blocked: \(error.localizedDescription)")
        }
    }

    func trustProject() {
        guard let project = selectionState.activeProject,
              WorkstationTrustPolicy.canTrust(project: project, phrase: projectState.trustPhrase) else {
            appendActivity(.commandBlocked, "Project trust phrase did not match.")
            return
        }
        selectionState.activeProject = WorkstationTrustPolicy.trustedCopy(of: project, phrase: projectState.trustPhrase)
        projectState.trustPhrase = ""
        projectState.currentProjectBrain = nil
        projectState.projectBrainStatus = .missing
        projectState.projectBrainMessage = "Trust status changed. Rescan Project Brain to refresh the report."
        appendActivity(.projectTrusted, "Project marked trusted after exact phrase.")
    }

    func safeProjectFileURL(project: WorkstationProject, relativePath: String) throws -> URL {
        let root = URL(fileURLWithPath: project.localPath, isDirectory: true).standardizedFileURL
        let cleaned = DeveloperProjectBrainPath.cleanRelativePath(relativePath)
        let url = root.appendingPathComponent(cleaned).standardizedFileURL
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard url.path.hasPrefix(rootPath),
              let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey]),
              values.isRegularFile == true,
              values.isSymbolicLink != true,
              (values.fileSize ?? 0) <= 512 * 1024 else {
            throw WorkstationProjectImportError.unsafePath
        }
        return url
    }
}
