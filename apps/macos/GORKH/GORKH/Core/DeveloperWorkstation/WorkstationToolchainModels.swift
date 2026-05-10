import Foundation

enum WorkstationToolchainComponent: String, Codable, CaseIterable, Identifiable {
    case solana
    case anchor
    case rustc
    case cargo
    case node
    case npm
    case git

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .solana:
            return "Solana CLI"
        case .anchor:
            return "Anchor CLI"
        case .rustc:
            return "Rust"
        case .cargo:
            return "Cargo"
        case .node:
            return "Node"
        case .npm:
            return "npm"
        case .git:
            return "Git"
        }
    }

    var executableName: String {
        rawValue
    }

    var versionArguments: [String] {
        ["--version"]
    }
}

enum WorkstationToolchainSource: String, Codable, Equatable {
    case bundled
    case managed
    case system
    case missing
    case incompatible
    case error

    var title: String {
        switch self {
        case .bundled:
            return "Bundled"
        case .managed:
            return "Managed"
        case .system:
            return "System"
        case .missing:
            return "Missing"
        case .incompatible:
            return "Incompatible"
        case .error:
            return "Error"
        }
    }
}

enum WorkstationToolchainStatus: String, Codable, Equatable {
    case available
    case missing
    case incompatible
    case error

    var title: String {
        switch self {
        case .available:
            return "Available"
        case .missing:
            return "Missing"
        case .incompatible:
            return "Incompatible"
        case .error:
            return "Error"
        }
    }
}

struct WorkstationToolchainResolution: Codable, Equatable, Identifiable {
    var id: WorkstationToolchainComponent { component }
    let component: WorkstationToolchainComponent
    let source: WorkstationToolchainSource
    let status: WorkstationToolchainStatus
    let executablePath: String?
    let version: String?
    let lastCheckedAt: Date?
    let message: String

    static func missing(_ component: WorkstationToolchainComponent, message: String = "Tool was not found in bundled, managed, or trusted system paths.") -> WorkstationToolchainResolution {
        WorkstationToolchainResolution(
            component: component,
            source: .missing,
            status: .missing,
            executablePath: nil,
            version: nil,
            lastCheckedAt: nil,
            message: message
        )
    }
}

struct WorkstationToolchainSnapshot: Codable, Equatable {
    let resolutions: [WorkstationToolchainResolution]

    static let unchecked = WorkstationToolchainSnapshot(
        resolutions: WorkstationToolchainComponent.allCases.map { .missing($0, message: "Not checked yet.") }
    )

    var availableCount: Int {
        resolutions.filter { $0.status == .available }.count
    }

    func resolution(for component: WorkstationToolchainComponent) -> WorkstationToolchainResolution? {
        resolutions.first { $0.component == component }
    }

    func isAvailable(_ component: WorkstationToolchainComponent) -> Bool {
        resolution(for: component)?.status == .available
    }
}
