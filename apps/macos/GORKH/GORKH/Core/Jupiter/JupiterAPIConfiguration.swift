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

    var priceBaseURL: URL {
        URL(string: hasAPIKey ? "https://api.jup.ag/price/v3" : "https://lite-api.jup.ag/price/v3")!
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
