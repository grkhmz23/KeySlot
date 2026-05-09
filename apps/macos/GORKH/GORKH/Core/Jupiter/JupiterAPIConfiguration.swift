import Foundation

struct JupiterAPIConfiguration: Equatable {
    static let appSpecificAPIKeyEnvironmentName = "GORKH_JUPITER_API_KEY"
    static let fallbackAPIKeyEnvironmentName = "JUPITER_API_KEY"

    let apiKey: String?

    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        apiKey = Self.apiKey(from: environment)
    }

    var hasAPIKey: Bool {
        apiKey != nil
    }

    var swapBaseURL: URL {
        URL(string: hasAPIKey ? "https://api.jup.ag/swap/v1" : "https://lite-api.jup.ag/swap/v1")!
    }

    var swapMode: JupiterSwapAPIMode {
        .metisV1
    }

    var swapQuoteEndpoint: URL {
        swapBaseURL.appendingPathComponent("quote")
    }

    var swapBuildEndpoint: URL {
        swapBaseURL.appendingPathComponent("swap")
    }

    var priceBaseURL: URL {
        URL(string: hasAPIKey ? "https://api.jup.ag/price/v3" : "https://lite-api.jup.ag/price/v3")!
    }

    var endpointCompatibility: [JupiterEndpointCompatibility] {
        [
            JupiterCompatibilityValidator.validate(url: swapQuoteEndpoint, kind: .quote, hasAPIKey: hasAPIKey),
            JupiterCompatibilityValidator.validate(url: swapBuildEndpoint, kind: .swapBuild, hasAPIKey: hasAPIKey),
            JupiterCompatibilityValidator.validate(url: priceBaseURL, kind: .price, hasAPIKey: hasAPIKey)
        ]
    }

    func applyAuthentication(to request: inout URLRequest) {
        guard let apiKey else {
            return
        }
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
    }

    static func apiKey(from environment: [String: String]) -> String? {
        [
            appSpecificAPIKeyEnvironmentName,
            fallbackAPIKeyEnvironmentName
        ]
            .compactMap { environment[$0]?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }
}
