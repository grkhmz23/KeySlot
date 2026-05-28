import Foundation

struct AnchorTomlSummary: Equatable {
    var programsByCluster: [String: [String: String]] = [:]
    var providerCluster: String?
    var scripts: [String: String] = [:]

    var allProgramIDsByName: [String: String] {
        programsByCluster.values.reduce(into: [:]) { partial, programs in
            programs.forEach { partial[$0.key] = $0.value }
        }
    }
}

enum AnchorTomlScanner {
    static func parse(_ text: String) -> AnchorTomlSummary {
        var summary = AnchorTomlSummary()
        var section = ""

        for rawLine in text.components(separatedBy: .newlines) {
            let line = stripComment(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            if line.hasPrefix("["), line.hasSuffix("]") {
                section = String(line.dropFirst().dropLast())
                continue
            }
            guard let (key, value) = parseAssignment(line) else { continue }
            if section.hasPrefix("programs.") {
                let cluster = String(section.dropFirst("programs.".count))
                var programs = summary.programsByCluster[cluster, default: [:]]
                programs[key] = value
                summary.programsByCluster[cluster] = programs
            } else if section == "provider", key == "cluster" {
                summary.providerCluster = value
            } else if section == "scripts" {
                summary.scripts[key] = value
            }
        }
        return summary
    }

    private static func stripComment(_ line: String) -> String {
        guard let index = line.firstIndex(of: "#") else {
            return line
        }
        return String(line[..<index])
    }

    static func parseAssignment(_ line: String) -> (String, String)? {
        guard let separator = line.firstIndex(of: "=") else {
            return nil
        }
        let key = line[..<separator].trimmingCharacters(in: .whitespacesAndNewlines)
        let rawValue = line[line.index(after: separator)...].trimmingCharacters(in: .whitespacesAndNewlines)
        let value = rawValue.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        guard !key.isEmpty, !value.isEmpty else {
            return nil
        }
        return (key, AgentSafetyRedactor.redact(value))
    }
}

struct CargoTomlSummary: Equatable {
    var packageName: String?
    var workspaceMembers: [String] = []
    var relevantDependencies: [String] = []
}

enum CargoTomlScanner {
    static let relevantDependencyNames = ["anchor-lang", "anchor-spl", "solana-program"]

    static func parse(_ text: String) -> CargoTomlSummary {
        var summary = CargoTomlSummary()
        var section = ""

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            if line.hasPrefix("["), line.hasSuffix("]") {
                section = String(line.dropFirst().dropLast())
                continue
            }
            guard let (key, value) = AnchorTomlScanner.parseAssignment(line) else { continue }
            if section == "package", key == "name" {
                summary.packageName = value
            }
            if section == "workspace", key == "members" {
                summary.workspaceMembers = parseStringArray(from: line)
            }
            if ["dependencies", "dev-dependencies", "workspace.dependencies"].contains(section),
               relevantDependencyNames.contains(key),
               !summary.relevantDependencies.contains(key) {
                summary.relevantDependencies.append(key)
            }
        }
        return summary
    }

    private static func parseStringArray(from line: String) -> [String] {
        guard let start = line.firstIndex(of: "["),
              let end = line.lastIndex(of: "]"),
              start < end else {
            return []
        }
        return line[line.index(after: start)..<end]
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"'"))) }
            .filter { !$0.isEmpty }
    }
}

struct PackageJsonSummary: Equatable {
    var dependencies: [String] = []
    var devDependencies: [String] = []
    var scriptNames: [String] = []

    var frameworkHints: [String] {
        let all = Set(dependencies + devDependencies)
        return [
            all.contains("@coral-xyz/anchor") ? "Anchor TypeScript client" : nil,
            all.contains("@solana/web3.js") ? "Solana web3.js" : nil,
            all.contains("react") ? "React" : nil,
            all.contains("vite") ? "Vite" : nil,
            all.contains("next") ? "Next.js" : nil
        ].compactMap { $0 }
    }
}

enum PackageJsonScanner {
    static func parse(_ data: Data) -> PackageJsonSummary {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return PackageJsonSummary()
        }
        let dependencies = (object["dependencies"] as? [String: Any] ?? [:]).keys.sorted()
        let devDependencies = (object["devDependencies"] as? [String: Any] ?? [:]).keys.sorted()
        let scripts = (object["scripts"] as? [String: Any] ?? [:]).keys.sorted()
        return PackageJsonSummary(
            dependencies: dependencies,
            devDependencies: devDependencies,
            scriptNames: scripts
        )
    }
}

enum AnchorIDLParser {
    static func parseBrain(relativePath: String, data: Data, modifiedAt: Date?) throws -> (idl: WorkstationIDL, brain: IDLBrain) {
        let idl = try WorkstationIDLParser.parse(data: data)
        let brain = IDLBrain(
            id: relativePath,
            relativePath: relativePath,
            programName: idl.name,
            programId: idl.address,
            instructions: idl.instructions.map(\.name),
            accounts: idl.accounts.map(\.name),
            types: idl.types.map(\.name),
            errors: idl.errors.map(\.name),
            events: idl.events.map(\.name),
            discriminators: idl.accounts.map { "\($0.name): \($0.discriminatorHex)" },
            source: relativePath.hasPrefix("target/idl/") ? "target/idl" : "idl",
            modifiedAt: modifiedAt
        )
        return (idl, brain)
    }
}

struct AnchorRustSourceSummary {
    var declareIDs: [(id: String, relativePath: String, line: Int)] = []
    var programModules: [(name: String, relativePath: String, line: Int)] = []
    var instructions: [InstructionBrain] = []
    var accountStructs: [AnchorAccountsStructSummary] = []
    var accountTypes: [AccountBrain] = []
    var pdaCandidates: [PDACandidate] = []
    var errorTypes: [String] = []
    var events: [String] = []
    var cpiHints: [String] = []
}

struct AnchorAccountsStructSummary: Equatable, Identifiable {
    var id: String { "\(relativePath):\(line):\(name)" }

    let name: String
    let relativePath: String
    let line: Int
    let accounts: [String]
    let signers: [String]
    let writable: [String]
    let constraints: [String]
    let pdaHints: [String]
}

enum AnchorRustSourceScanner {
    static func scan(relativePath: String, text: String) -> AnchorRustSourceSummary {
        let lines = text.components(separatedBy: .newlines)
        var summary = AnchorRustSourceSummary()
        var pendingProgramLine: Int?
        var pendingAccountsDeriveLine: Int?
        var pendingAccountStructLine: Int?
        var pendingEventLine: Int?
        var pendingErrorLine: Int?
        var pendingAccountAttributes: [(text: String, line: Int)] = []
        var currentAccountsStruct: (name: String, line: Int, accounts: [String], signers: [String], writable: [String], constraints: [String], pdaHints: [String])?
        var currentAccountType: (name: String, line: Int, fields: [String])?

        for (offset, rawLine) in lines.enumerated() {
            let lineNumber = offset + 1
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if let id = capture(in: line, pattern: #"declare_id!\("([^"]+)"\)"#) {
                summary.declareIDs.append((id, relativePath, lineNumber))
            }
            if line == "#[program]" {
                pendingProgramLine = lineNumber
                continue
            }
            if line == "#[derive(Accounts)]" {
                pendingAccountsDeriveLine = lineNumber
                continue
            }
            if line == "#[account]" || line.hasPrefix("#[account(") {
                if line.hasPrefix("#[account(") {
                    pendingAccountAttributes.append((line, lineNumber))
                } else {
                    pendingAccountStructLine = lineNumber
                }
                continue
            }
            if line == "#[event]" {
                pendingEventLine = lineNumber
                continue
            }
            if line == "#[error_code]" {
                pendingErrorLine = lineNumber
                continue
            }
            if line.hasPrefix("#[account(") {
                pendingAccountAttributes.append((line, lineNumber))
                continue
            }

            if let module = capture(in: line, pattern: #"pub\s+mod\s+([A-Za-z_][A-Za-z0-9_]*)"#),
               let start = pendingProgramLine {
                summary.programModules.append((module, relativePath, start))
                pendingProgramLine = nil
            }

            if let functionName = capture(in: line, pattern: #"pub\s+fn\s+([A-Za-z_][A-Za-z0-9_]*)\s*\("#) {
                let context = capture(in: line, pattern: #"Context<([A-Za-z_][A-Za-z0-9_]*)>"#)
                let args = parseFunctionArgs(from: line)
                let cpiHints = line.contains("CpiContext") ? ["CpiContext"] : []
                summary.instructions.append(InstructionBrain(
                    id: "\(relativePath):\(lineNumber):\(functionName)",
                    name: functionName,
                    sourceRelativePath: relativePath,
                    sourceLineStart: lineNumber,
                    args: args,
                    accounts: context.map { [$0] } ?? [],
                    signerAccounts: [],
                    writableAccounts: [],
                    anchorConstraints: [],
                    cpiHints: cpiHints,
                    pdaHints: [],
                    confidence: .medium
                ))
            }

            if let structName = capture(in: line, pattern: #"pub\s+struct\s+([A-Za-z_][A-Za-z0-9_]*)"#) {
                if let start = pendingAccountsDeriveLine {
                    currentAccountsStruct = (structName, start, [], [], [], [], [])
                    pendingAccountsDeriveLine = nil
                    pendingAccountAttributes.removeAll()
                    continue
                }
                if let start = pendingAccountStructLine {
                    currentAccountType = (structName, start, [])
                    pendingAccountStructLine = nil
                    continue
                }
                if pendingEventLine != nil {
                    summary.events.append(structName)
                    pendingEventLine = nil
                }
                if pendingErrorLine != nil {
                    summary.errorTypes.append(structName)
                    pendingErrorLine = nil
                }
            }

            if var accountsStruct = currentAccountsStruct {
                if line == "}" {
                    summary.accountStructs.append(AnchorAccountsStructSummary(
                        name: accountsStruct.name,
                        relativePath: relativePath,
                        line: accountsStruct.line,
                        accounts: accountsStruct.accounts,
                        signers: accountsStruct.signers,
                        writable: accountsStruct.writable,
                        constraints: accountsStruct.constraints,
                        pdaHints: accountsStruct.pdaHints
                    ))
                    currentAccountsStruct = nil
                    continue
                }
                if let field = parseRustField(line) {
                    accountsStruct.accounts.append(field.name)
                    let attrs = pendingAccountAttributes.map(\.text)
                    let attrText = attrs.joined(separator: " ")
                    let constraints = attrs.map(cleanAttribute)
                    accountsStruct.constraints.append(contentsOf: constraints)
                    if field.type.contains("Signer") || attrText.contains("signer") {
                        accountsStruct.signers.append(field.name)
                    }
                    if attrText.contains("mut") || attrText.contains("init") {
                        accountsStruct.writable.append(field.name)
                    }
                    if attrText.contains("seeds") || line.contains("find_program_address") || line.contains("create_program_address") {
                        let seedSummary = parseSeedSummary(attrText)
                        accountsStruct.pdaHints.append(seedSummary)
                        summary.pdaCandidates.append(PDACandidate(
                            id: "\(relativePath):\(lineNumber):\(field.name)",
                            label: field.name,
                            sourceRelativePath: relativePath,
                            sourceLineStart: lineNumber,
                            programIdSource: "declare_id",
                            seeds: seedSummary.isEmpty ? [] : [seedSummary],
                            bumpUsage: attrText.contains("bump") ? "bump constraint present" : nil,
                            accountType: field.type,
                            instructionName: accountsStruct.name,
                            confidence: seedSummary.isEmpty ? .low : .medium,
                            unsupportedReason: seedSummary.isEmpty ? "PDA hint found but seed expression was not parsed." : nil
                        ))
                    }
                    pendingAccountAttributes.removeAll()
                    currentAccountsStruct = accountsStruct
                }
            }

            if var accountType = currentAccountType {
                if line == "}" {
                    summary.accountTypes.append(AccountBrain(
                        id: "\(relativePath):\(accountType.line):\(accountType.name)",
                        name: accountType.name,
                        sourceRelativePath: relativePath,
                        sourceLineStart: accountType.line,
                        fields: accountType.fields,
                        discriminator: nil,
                        idlTypeRef: nil,
                        confidence: .medium
                    ))
                    currentAccountType = nil
                    continue
                }
                if let field = parseRustField(line) {
                    accountType.fields.append("\(field.name): \(field.type)")
                    currentAccountType = accountType
                }
            }

            if line.contains("CpiContext") || line.contains("invoke_signed") || line.contains("invoke(") {
                summary.cpiHints.append("\(relativePath):\(lineNumber)")
            }
            if line.contains("Pubkey::find_program_address") || line.contains("Pubkey::create_program_address") {
                summary.pdaCandidates.append(PDACandidate(
                    id: "\(relativePath):\(lineNumber):manual-pda",
                    label: "Manual PDA derivation",
                    sourceRelativePath: relativePath,
                    sourceLineStart: lineNumber,
                    programIdSource: nil,
                    seeds: [],
                    bumpUsage: line.contains("find_program_address") ? "find_program_address bump search" : nil,
                    accountType: nil,
                    instructionName: nil,
                    confidence: .low,
                    unsupportedReason: "Manual PDA expression requires semantic Rust parsing."
                ))
            }
        }

        return summary
    }

    private static func parseFunctionArgs(from line: String) -> [String] {
        guard let start = line.firstIndex(of: "("),
              let end = line.lastIndex(of: ")"),
              start < end else {
            return []
        }
        return line[line.index(after: start)..<end]
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.hasPrefix("ctx:") && !$0.isEmpty }
    }

    private static func parseRustField(_ line: String) -> (name: String, type: String)? {
        guard let range = line.range(of: #"pub\s+([A-Za-z_][A-Za-z0-9_]*)\s*:\s*([^,]+)"#, options: .regularExpression) else {
            return nil
        }
        let match = String(line[range])
        guard let separator = match.firstIndex(of: ":") else {
            return nil
        }
        let name = match[..<separator]
            .replacingOccurrences(of: "pub", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let type = match[match.index(after: separator)...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ","))
        return (name, type)
    }

    private static func capture(in line: String, pattern: String) -> String? {
        guard let range = line.range(of: pattern, options: .regularExpression) else {
            return nil
        }
        let match = String(line[range])
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let result = regex.firstMatch(in: match, range: NSRange(match.startIndex..., in: match)),
              result.numberOfRanges > 1,
              let captureRange = Range(result.range(at: 1), in: match) else {
            return nil
        }
        return String(match[captureRange])
    }

    nonisolated private static func cleanAttribute(_ attribute: String) -> String {
        attribute
            .replacingOccurrences(of: "#[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseSeedSummary(_ attribute: String) -> String {
        guard let start = attribute.range(of: "seeds")?.lowerBound,
              let bracketStart = attribute[start...].firstIndex(of: "["),
              let bracketEnd = attribute[bracketStart...].firstIndex(of: "]") else {
            return ""
        }
        return attribute[attribute.index(after: bracketStart)..<bracketEnd]
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
