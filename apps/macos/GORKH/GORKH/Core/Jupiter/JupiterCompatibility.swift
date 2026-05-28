import Foundation

enum JupiterSwapAPIMode: String, Codable, CaseIterable, Equatable {
    case metisV1
    case swapV2OrderExecuteCandidate
    case swapV2RouterCandidate
    case unsupported

    var displayName: String {
        switch self {
        case .metisV1:
            return "Metis v1 compatibility mode"
        case .swapV2OrderExecuteCandidate:
            return "Swap V2 order/execute candidate"
        case .swapV2RouterCandidate:
            return "Swap V2 router candidate"
        case .unsupported:
            return "Unsupported Jupiter mode"
        }
    }

    var warningText: String {
        switch self {
        case .metisV1:
            return "Metis v1 is no longer actively maintained by Jupiter. KeySlot keeps it in compatibility mode until Swap V2 is reviewed."
        case .swapV2OrderExecuteCandidate:
            return "Swap V2 order/execute requires a separate review before execution because Jupiter manages landing through /execute."
        case .swapV2RouterCandidate:
            return "Swap V2 router/build requires a separate native transaction assembly path before execution."
        case .unsupported:
            return "Swap execution is locked for unsupported Jupiter endpoint configuration."
        }
    }

    var allowsCurrentExecution: Bool {
        self == .metisV1
    }
}

enum JupiterEndpointKind: String, Codable, Equatable {
    case quote
    case swapBuild
    case price
    case order
    case execute
    case limitOrder
    case unknown
}

struct JupiterEndpointCompatibility: Codable, Equatable {
    let kind: JupiterEndpointKind
    let url: String
    let mode: JupiterSwapAPIMode
    let isAllowedForCurrentExecution: Bool
    let requiresAPIKey: Bool
    let usesLiteEndpoint: Bool
    let warnings: [String]
    let blockingReasons: [String]

    var canUse: Bool {
        blockingReasons.isEmpty
    }
}

enum JupiterCompatibilityValidator {
    static func validate(
        url: URL,
        kind: JupiterEndpointKind,
        hasAPIKey: Bool
    ) -> JupiterEndpointCompatibility {
        let normalizedPath = url.path.lowercased()
        let host = (url.host ?? "").lowercased()
        var warnings: [String] = []
        var blockingReasons: [String] = []

        if url.scheme?.lowercased() != "https" {
            blockingReasons.append("Jupiter endpoint must use HTTPS.")
        }
        if host != "api.jup.ag", host != "lite-api.jup.ag" {
            blockingReasons.append("Jupiter endpoint host is not allowlisted.")
        }

        let usesLiteEndpoint = host == "lite-api.jup.ag"
        if !hasAPIKey, host == "api.jup.ag" {
            blockingReasons.append("Paid Jupiter endpoint requires an API key.")
        }
        if hasAPIKey, usesLiteEndpoint {
            warnings.append("API key is present but endpoint is using the lite host.")
        }

        let detectedMode = mode(for: normalizedPath)
        let detectedKind = endpointKind(for: normalizedPath)
        if detectedKind != kind {
            blockingReasons.append("Jupiter endpoint path does not match expected \(kind.rawValue) endpoint.")
        }

        switch kind {
        case .quote:
            if normalizedPath != "/swap/v1/quote" {
                blockingReasons.append("Current quote flow only allows /swap/v1/quote.")
            }
        case .swapBuild:
            if normalizedPath != "/swap/v1/swap" {
                blockingReasons.append("Current swap build flow only allows /swap/v1/swap.")
            }
        case .price:
            if normalizedPath != "/price/v3" {
                blockingReasons.append("Current price flow only allows /price/v3.")
            }
        case .order, .execute:
            blockingReasons.append("Swap V2 order/execute is review-only and not enabled for execution.")
        case .limitOrder:
            blockingReasons.append("Limit order endpoints are forbidden in Wallet Swap.")
        case .unknown:
            blockingReasons.append("Unknown Jupiter endpoint is forbidden.")
        }

        if normalizedPath.contains("limit") || normalizedPath.contains("trigger") {
            blockingReasons.append("Jupiter limit/trigger endpoints are forbidden in this phase.")
        }

        let requiresAPIKey = host == "api.jup.ag" || normalizedPath.hasPrefix("/swap/v2")
        return JupiterEndpointCompatibility(
            kind: kind,
            url: redactedURLString(url),
            mode: detectedMode,
            isAllowedForCurrentExecution: detectedMode.allowsCurrentExecution && blockingReasons.isEmpty,
            requiresAPIKey: requiresAPIKey,
            usesLiteEndpoint: usesLiteEndpoint,
            warnings: warnings,
            blockingReasons: Array(Set(blockingReasons)).sorted()
        )
    }

    static func mode(for path: String) -> JupiterSwapAPIMode {
        let normalized = path.lowercased()
        if normalized.hasPrefix("/swap/v1/") {
            return .metisV1
        }
        if normalized == "/swap/v2/order" || normalized == "/swap/v2/execute" {
            return .swapV2OrderExecuteCandidate
        }
        if normalized == "/swap/v2/build" || normalized == "/tx/v1/submit" {
            return .swapV2RouterCandidate
        }
        return .unsupported
    }

    static func endpointKind(for path: String) -> JupiterEndpointKind {
        let normalized = path.lowercased()
        switch normalized {
        case "/swap/v1/quote":
            return .quote
        case "/swap/v1/swap", "/swap/v2/build":
            return .swapBuild
        case "/price/v3":
            return .price
        case "/swap/v2/order":
            return .order
        case "/swap/v2/execute", "/tx/v1/submit":
            return .execute
        default:
            if normalized.contains("limit") || normalized.contains("trigger") {
                return .limitOrder
            }
            return .unknown
        }
    }

    static func redactedURLString(_ url: URL) -> String {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.query = nil
        return components?.url?.absoluteString ?? url.absoluteString
    }
}
