import AppKit
import Foundation

extension DeveloperWorkstationStore {
    func copyEvidenceProgramID(_ programId: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(programId, forType: .string)
        appendActivity(.localnetSmokeEvidenceViewed, "Program id copied from safe evidence.")
    }

    func openEvidenceIDLBrowser() {
        selectionState.selectedSection = .idlBrowser
        appendActivity(.localnetSmokeEvidenceViewed, "IDL Browser opened from program evidence.")
    }

    func openEvidenceLogs(_ recordProgramID: String?) {
        if let recordProgramID {
            rpcState.programID = recordProgramID
        }
        selectionState.selectedSection = .logs
        appendActivity(.localnetSmokeEvidenceViewed, "Logs opened from program evidence.")
    }

    func copySignature(_ signature: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(signature, forType: .string)
        appendActivity(.localnetSmokeEvidenceViewed, "Signature copied from release record.")
    }

    func copyReleaseProgramID(_ programId: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(programId, forType: .string)
        appendActivity(.localnetSmokeEvidenceViewed, "Program id copied from release record.")
    }

    func openIDLDriftFromRelease() {
        selectionState.selectedSection = .idlDrift
        appendActivity(.localnetSmokeEvidenceViewed, "IDL Drift opened from release record.")
    }

    func openLogsFromRelease(_ recordProgramID: String?) {
        if let recordProgramID {
            rpcState.programID = recordProgramID
        }
        selectionState.selectedSection = .logs
        appendActivity(.localnetSmokeEvidenceViewed, "Logs opened from release record.")
    }

    func appendActivity(_ kind: WorkstationActivityKind, _ message: String, details: [String: String] = [:]) {
        evidenceState.activity.insert(WorkstationActivityEvent(kind: kind, message: message, details: details), at: 0)
        evidenceState.activity = Array(evidenceState.activity.prefix(100))
    }
}
