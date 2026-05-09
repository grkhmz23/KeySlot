import Foundation

enum CloakHelperPathError: LocalizedError, Equatable {
    case helperExecutionDisabled
    case disallowedHelperPath(String)
    case disallowedNodeExecutable(String)
    case nodeExecutableUnavailable
    case projectRootMissing

    var errorDescription: String? {
        switch self {
        case .helperExecutionDisabled:
            return "Cloak helper invocation is disabled."
        case .disallowedHelperPath(let path):
            return "Cloak helper path is not allowlisted: \(path)."
        case .disallowedNodeExecutable(let path):
            return "Node executable path is not allowlisted: \(path)."
        case .nodeExecutableUnavailable:
            return "No allowlisted Node executable is available."
        case .projectRootMissing:
            return "Project root is required for Cloak helper invocation."
        }
    }
}

struct CloakHelperResolvedPath: Equatable {
    let nodeExecutable: URL
    let helperScript: URL
    let helperRelativePath: String
}

protocol CloakHelperPathResolving {
    func resolve(policy: CloakBridgeExecutionPolicy, projectRoot: URL?) throws -> CloakHelperResolvedPath
}

struct CloakHelperPathResolver: CloakHelperPathResolving {
    static let allowedRelativePath = "tools/cloak-bridge/src/index.ts"

    func resolve(policy: CloakBridgeExecutionPolicy, projectRoot: URL?) throws -> CloakHelperResolvedPath {
        guard policy.helperExecutionEnabled else {
            throw CloakHelperPathError.helperExecutionDisabled
        }
        guard policy.allowlistedHelperRelativePath == Self.allowedRelativePath,
              isSafeRelativeHelperPath(policy.allowlistedHelperRelativePath) else {
            throw CloakHelperPathError.disallowedHelperPath(policy.allowlistedHelperRelativePath)
        }
        guard let projectRoot else {
            throw CloakHelperPathError.projectRootMissing
        }

        let nodeExecutable = try resolveNodeExecutable(candidates: policy.allowedNodeExecutablePaths)
        let helperScript = projectRoot.appendingPathComponent(policy.allowlistedHelperRelativePath)
        return CloakHelperResolvedPath(
            nodeExecutable: nodeExecutable,
            helperScript: helperScript,
            helperRelativePath: policy.allowlistedHelperRelativePath
        )
    }

    func resolveNodeExecutable(candidates: [String]) throws -> URL {
        for candidate in candidates {
            guard isAllowedNodeExecutablePath(candidate) else {
                throw CloakHelperPathError.disallowedNodeExecutable(candidate)
            }
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return URL(fileURLWithPath: candidate)
            }
        }

        throw CloakHelperPathError.nodeExecutableUnavailable
    }

    func isAllowedNodeExecutablePath(_ path: String) -> Bool {
        CloakBridgeExecutionPolicy.disabled.allowedNodeExecutablePaths.contains(path)
    }

    private func isSafeRelativeHelperPath(_ path: String) -> Bool {
        !path.hasPrefix("/")
            && !path.contains("..")
            && !path.contains("\\")
            && !path.contains(";")
            && !path.contains("\n")
            && path == Self.allowedRelativePath
    }
}
