import Foundation

enum ZerionCLIInstallStatus: String, Codable, Equatable {
    case unchecked
    case installed
    case missing
    case unavailable
    case incompatible
    case error

    var label: String {
        switch self {
        case .unchecked:
            return "Not checked"
        case .installed:
            return "Installed"
        case .missing:
            return "Missing"
        case .unavailable:
            return "Unavailable"
        case .incompatible:
            return "Incompatible"
        case .error:
            return "Error"
        }
    }
}

enum ZerionSecretStatus: String, Codable, Equatable {
    case presentRedacted = "present_redacted"
    case missing
    case malformedRedacted = "malformed_redacted"
    case unknown

    var label: String {
        switch self {
        case .presentRedacted:
            return "Present"
        case .missing:
            return "Missing"
        case .malformedRedacted:
            return "Malformed"
        case .unknown:
            return "Unknown"
        }
    }
}

enum ZerionPolicyReadStatus: String, Codable, Equatable {
    case unchecked
    case loaded
    case unavailable
    case error

    var label: String {
        switch self {
        case .unchecked:
            return "Not checked"
        case .loaded:
            return "Loaded"
        case .unavailable:
            return "Unavailable"
        case .error:
            return "Error"
        }
    }
}

enum ZerionCommandRunStatus: String, Codable, Equatable {
    case succeeded
    case failed
    case blocked
    case timedOut = "timed_out"
}

struct ZerionCLIPathResolution: Codable, Equatable {
    let status: ZerionCLIInstallStatus
    let executablePath: String?
    let reason: String?

    static let missing = ZerionCLIPathResolution(
        status: .missing,
        executablePath: nil,
        reason: "Zerion CLI was not found in an allowlisted executable path."
    )
}

struct ZerionCommandResult: Codable, Equatable {
    let command: String
    let status: ZerionCommandRunStatus
    let exitCode: Int32?
    let stdoutSummary: String
    let stderrSummary: String
    let completedAt: Date

    static func blocked(command: String, reason: String) -> ZerionCommandResult {
        ZerionCommandResult(
            command: command,
            status: .blocked,
            exitCode: nil,
            stdoutSummary: "",
            stderrSummary: ZerionRedaction.redact(reason),
            completedAt: Date()
        )
    }
}

struct ZerionStatusSnapshot: Codable, Equatable {
    let cliStatus: ZerionCLIInstallStatus
    let executablePath: String?
    let nodeStatus: ZerionCLIInstallStatus
    let apiKeyStatus: ZerionSecretStatus
    let agentTokenStatus: ZerionSecretStatus
    let policyStatus: ZerionPolicyReadStatus
    let walletCount: Int?
    let policyCount: Int?
    let tokenCount: Int?
    let supportedChains: [String]
    let errors: [String]
    let checkedAt: Date

    static let unchecked = ZerionStatusSnapshot(
        cliStatus: .unchecked,
        executablePath: nil,
        nodeStatus: .unchecked,
        apiKeyStatus: .unknown,
        agentTokenStatus: .unknown,
        policyStatus: .unchecked,
        walletCount: nil,
        policyCount: nil,
        tokenCount: nil,
        supportedChains: [],
        errors: [],
        checkedAt: Date()
    )
}
