import Foundation

enum WorkstationComputeMeasurementSource: String, Codable, CaseIterable, Identifiable {
    case computeLab = "compute_lab"
    case transactionDebugger = "transaction_debugger"
    case testOutput = "test_output"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .computeLab:
            return "Compute Lab"
        case .transactionDebugger:
            return "Transaction Debugger"
        case .testOutput:
            return "Test Output"
        }
    }
}

struct WorkstationComputeMeasurement: Codable, Equatable, Identifiable {
    let id: UUID
    let projectID: String?
    let instructionName: String
    let source: WorkstationComputeMeasurementSource
    let computeUnits: UInt64
    let timestamp: Date
    let signature: String?
    let evidenceId: String?
    let logSummary: String

    init(
        id: UUID = UUID(),
        projectID: String?,
        instructionName: String,
        source: WorkstationComputeMeasurementSource,
        computeUnits: UInt64,
        timestamp: Date = Date(),
        signature: String? = nil,
        evidenceId: String? = nil,
        logSummary: String = ""
    ) {
        self.id = id
        self.projectID = projectID.map(AgentSafetyRedactor.redact)
        let cleanInstruction = instructionName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.instructionName = AgentSafetyRedactor.redact(cleanInstruction.isEmpty ? "unknown" : cleanInstruction)
        self.source = source
        self.computeUnits = computeUnits
        self.timestamp = timestamp
        self.signature = signature.map(AgentSafetyRedactor.redact)
        self.evidenceId = evidenceId.map(AgentSafetyRedactor.redact)
        self.logSummary = WorkstationCommandRunner.safeSummary(logSummary)
    }
}

struct WorkstationComputeBaseline: Codable, Equatable, Identifiable {
    let id: UUID
    let projectID: String?
    let instructionName: String
    let measurementId: UUID
    let computeUnits: UInt64
    let selectedAt: Date
}

enum WorkstationComputeRegressionStatus: String, Codable, Equatable {
    case noBaseline = "no_baseline"
    case improved
    case stable
    case regressed

    var title: String {
        switch self {
        case .noBaseline:
            return "No baseline"
        case .improved:
            return "Improved"
        case .stable:
            return "Stable"
        case .regressed:
            return "Regressed"
        }
    }
}

struct WorkstationComputeRegressionRow: Codable, Equatable, Identifiable {
    var id: String { "\(instructionName):\(latest.id.uuidString)" }

    let instructionName: String
    let latest: WorkstationComputeMeasurement
    let baseline: WorkstationComputeBaseline?
    let delta: Int64?
    let status: WorkstationComputeRegressionStatus
}

struct ComputeRegressionService {
    static func measurements(
        fromLogs logs: [String],
        projectID: String?,
        instructionName: String,
        source: WorkstationComputeMeasurementSource,
        signature: String? = nil,
        evidenceId: String? = nil
    ) -> [WorkstationComputeMeasurement] {
        logs.flatMap { log in
            parseComputeUnits(from: log).map { units in
                WorkstationComputeMeasurement(
                    projectID: projectID,
                    instructionName: instructionName,
                    source: source,
                    computeUnits: units,
                    signature: signature,
                    evidenceId: evidenceId,
                    logSummary: log
                )
            }
        }
    }

    static func parseComputeUnits(from log: String) -> [UInt64] {
        let patterns = [
            #"consumed\s+([0-9][0-9,_]*)\s+of\s+[0-9][0-9,_]*\s+compute units"#,
            #"units consumed[:=]\s*([0-9][0-9,_]*)"#,
            #"compute units[:=]\s*([0-9][0-9,_]*)"#
        ]
        var units: [UInt64] = []
        for pattern in patterns {
            let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let range = NSRange(log.startIndex..<log.endIndex, in: log)
            regex?.enumerateMatches(in: log, range: range) { match, _, _ in
                guard let match,
                      match.numberOfRanges > 1,
                      let valueRange = Range(match.range(at: 1), in: log) else {
                    return
                }
                let raw = log[valueRange].replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "_", with: "")
                if let value = UInt64(raw) {
                    units.append(value)
                }
            }
        }
        return units
    }

    static func selectBaseline(from measurement: WorkstationComputeMeasurement) -> WorkstationComputeBaseline {
        WorkstationComputeBaseline(
            id: UUID(),
            projectID: measurement.projectID,
            instructionName: measurement.instructionName,
            measurementId: measurement.id,
            computeUnits: measurement.computeUnits,
            selectedAt: Date()
        )
    }

    static func rows(measurements: [WorkstationComputeMeasurement], baselines: [WorkstationComputeBaseline]) -> [WorkstationComputeRegressionRow] {
        let grouped = Dictionary(grouping: measurements) { $0.instructionName }
        return grouped.compactMap { instruction, entries in
            guard let latest = entries.sorted(by: { $0.timestamp > $1.timestamp }).first else {
                return nil
            }
            let baseline = baselines
                .filter { $0.instructionName == instruction }
                .sorted { $0.selectedAt > $1.selectedAt }
                .first
            let delta = baseline.map { Int64(latest.computeUnits) - Int64($0.computeUnits) }
            let status: WorkstationComputeRegressionStatus
            if let delta {
                if delta > 0 {
                    status = .regressed
                } else if delta < 0 {
                    status = .improved
                } else {
                    status = .stable
                }
            } else {
                status = .noBaseline
            }
            return WorkstationComputeRegressionRow(
                instructionName: instruction,
                latest: latest,
                baseline: baseline,
                delta: delta,
                status: status
            )
        }
        .sorted { $0.instructionName < $1.instructionName }
    }
}

final class WorkstationComputeRegressionStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    struct Payload: Codable, Equatable {
        var measurements: [WorkstationComputeMeasurement]
        var baselines: [WorkstationComputeBaseline]

        static let empty = Payload(measurements: [], baselines: [])
    }

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultURL()
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() -> Payload {
        guard let data = try? Data(contentsOf: fileURL) else {
            return .empty
        }
        return (try? decoder.decode(Payload.self, from: data)) ?? .empty
    }

    func append(measurements: [WorkstationComputeMeasurement]) throws -> Payload {
        var payload = load()
        payload.measurements.insert(contentsOf: measurements, at: 0)
        payload.measurements = Array(payload.measurements.prefix(300))
        try save(payload)
        return payload
    }

    func selectBaseline(_ baseline: WorkstationComputeBaseline) throws -> Payload {
        var payload = load()
        payload.baselines.removeAll { $0.instructionName == baseline.instructionName && $0.projectID == baseline.projectID }
        payload.baselines.insert(baseline, at: 0)
        try save(payload)
        return payload
    }

    func save(_ payload: Payload) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(payload).write(to: fileURL, options: [.atomic])
    }

    static func defaultURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("KeySlot", isDirectory: true)
            .appendingPathComponent("DeveloperWorkstation", isDirectory: true)
            .appendingPathComponent("compute-regression.json")
    }
}
