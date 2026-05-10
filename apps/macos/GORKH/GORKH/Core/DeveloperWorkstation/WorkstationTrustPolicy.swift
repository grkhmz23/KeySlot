import Foundation

enum WorkstationTrustPolicy {
    static let requiredPhrase = "I trust this project and understand build scripts may run local code."

    static func canTrust(project: WorkstationProject, phrase: String) -> Bool {
        project.localPath.isEmpty == false
            && phrase.trimmingCharacters(in: .whitespacesAndNewlines) == requiredPhrase
    }

    static func trustedCopy(of project: WorkstationProject, phrase: String) -> WorkstationProject {
        guard canTrust(project: project, phrase: phrase) else {
            return project
        }
        var updated = project
        updated.trustStatus = .trusted
        updated.warnings = ["Trusted by explicit phrase. Build scripts may run local code when commands are approved."]
        return updated
    }

    static func blocksExecution(project: WorkstationProject?) -> String? {
        guard let project, project.localPath.isEmpty == false else {
            return "No project is selected."
        }
        guard project.trustStatus == .trusted else {
            return "Project is untrusted. Browsing is allowed; build, deploy, upgrade, close, and scripts are blocked."
        }
        return nil
    }
}
