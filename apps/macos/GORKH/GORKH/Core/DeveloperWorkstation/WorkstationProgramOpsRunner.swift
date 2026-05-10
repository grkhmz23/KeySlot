import Foundation

enum WorkstationProgramOpsRunnerError: LocalizedError, Equatable {
    case operationBlocked([String])
    case missingExecutable(WorkstationToolchainComponent)
    case missingProjectPath
    case missingTemporaryKeypair
    case unsupportedOperation

    var errorDescription: String? {
        switch self {
        case .operationBlocked(let reasons):
            return "Program operation blocked: \(reasons.joined(separator: "; "))"
        case .missingExecutable(let component):
            return "\(component.displayName) executable is unavailable."
        case .missingProjectPath:
            return "A trusted project path is required."
        case .missingTemporaryKeypair:
            return "A temporary developer keypair file is required."
        case .unsupportedOperation:
            return "This program operation is not supported in this Workstation phase."
        }
    }
}

struct WorkstationProgramOpsRunner {
    static func preparePlan(
        request: WorkstationProgramOperationRequest,
        keypairPath: String?
    ) throws -> WorkstationCommandPlan {
        let decision = WorkstationProgramManager.evaluate(request)
        guard decision.isAllowed else {
            throw WorkstationProgramOpsRunnerError.operationBlocked(decision.reasons)
        }

        switch request.operation {
        case .anchorBuild:
            let anchor = try executable(.anchor, snapshot: request.toolchain)
            guard let projectPath = request.project?.localPath else {
                throw WorkstationProgramOpsRunnerError.missingProjectPath
            }
            return WorkstationCommandBuilders.anchorBuild(anchorPath: anchor, projectPath: projectPath)

        case .anchorDeploy:
            let anchor = try executable(.anchor, snapshot: request.toolchain)
            guard let projectPath = request.project?.localPath else {
                throw WorkstationProgramOpsRunnerError.missingProjectPath
            }
            guard let keypairPath else {
                throw WorkstationProgramOpsRunnerError.missingTemporaryKeypair
            }
            return WorkstationCommandBuilders.anchorDeploy(
                anchorPath: anchor,
                projectPath: projectPath,
                cluster: request.cluster,
                keyFilePath: keypairPath
            )

        case .solanaProgramDeploy:
            let solana = try executable(.solana, snapshot: request.toolchain)
            guard let artifactPath = request.artifactPath else {
                throw WorkstationProgramOpsRunnerError.unsupportedOperation
            }
            guard let keypairPath else {
                throw WorkstationProgramOpsRunnerError.missingTemporaryKeypair
            }
            return WorkstationCommandBuilders.solanaProgramDeploy(
                solanaPath: solana,
                artifactPath: artifactPath,
                cluster: request.cluster,
                keyFilePath: keypairPath
            )

        case .solanaProgramShow:
            let solana = try executable(.solana, snapshot: request.toolchain)
            guard let programID = request.programID else {
                throw WorkstationProgramOpsRunnerError.unsupportedOperation
            }
            return WorkstationCommandBuilders.solanaProgramShow(
                solanaPath: solana,
                programID: programID,
                cluster: request.cluster
            )

        case .solanaProgramClose:
            let solana = try executable(.solana, snapshot: request.toolchain)
            guard let programID = request.programID else {
                throw WorkstationProgramOpsRunnerError.unsupportedOperation
            }
            guard let keypairPath else {
                throw WorkstationProgramOpsRunnerError.missingTemporaryKeypair
            }
            return WorkstationCommandBuilders.solanaProgramClose(
                solanaPath: solana,
                programID: programID,
                cluster: request.cluster,
                keyFilePath: keypairPath
            )

        case .solanaSetUpgradeAuthority:
            throw WorkstationProgramOpsRunnerError.unsupportedOperation
        }
    }

    private static func executable(
        _ component: WorkstationToolchainComponent,
        snapshot: WorkstationToolchainSnapshot
    ) throws -> String {
        guard let path = snapshot.resolution(for: component)?.executablePath else {
            throw WorkstationProgramOpsRunnerError.missingExecutable(component)
        }
        return path
    }
}
