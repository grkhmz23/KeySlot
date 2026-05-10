import Foundation

struct AgentHostedAPIConfiguration: Equatable {
    static let baseURLEnvironmentName = "GORKH_AGENT_API_BASE_URL"
    static let apiKeyEnvironmentName = "GORKH_AGENT_API_KEY"

    let baseURL: URL?
    let apiKeyStatus: AgentHostedAPIKeyStatus
    private let apiKey: String?

    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        let rawBaseURL = environment[Self.baseURLEnvironmentName]?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let rawBaseURL, rawBaseURL.isEmpty == false, let url = URL(string: rawBaseURL), url.scheme?.lowercased() == "https" {
            baseURL = url
        } else {
            baseURL = nil
        }

        let rawAPIKey = environment[Self.apiKeyEnvironmentName]?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let rawAPIKey, rawAPIKey.isEmpty == false {
            apiKey = rawAPIKey
            apiKeyStatus = .presentRedacted
        } else {
            apiKey = nil
            apiKeyStatus = .missing
        }
    }

    var endpointURL: URL? {
        baseURL?.appendingPathComponent("v1").appendingPathComponent("agent").appendingPathComponent("chat")
    }

    var endpointHost: String? {
        baseURL?.host
    }

    func applyAuthentication(to request: inout URLRequest) {
        guard let apiKey else {
            return
        }
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    }
}

enum AgentHostedAPIError: Error, Equatable {
    case missingEndpoint
    case invalidResponse
    case httpStatus(Int, String)
    case transport(String)
    case validation(String)
}

protocol AgentHTTPTransport {
    func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionAgentHTTPTransport: AgentHTTPTransport {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AgentHostedAPIError.invalidResponse
        }
        return (data, httpResponse)
    }
}

struct AgentHostedAPIClient {
    let configuration: AgentHostedAPIConfiguration
    private let transport: any AgentHTTPTransport
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(
        configuration: AgentHostedAPIConfiguration = AgentHostedAPIConfiguration(),
        transport: any AgentHTTPTransport = URLSessionAgentHTTPTransport()
    ) {
        self.configuration = configuration
        self.transport = transport
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
    }

    func send(_ requestPayload: AgentLLMChatRequest) async throws -> AgentLLMChatResponse {
        try await sendValidated(requestPayload).response
    }

    func sendValidated(_ requestPayload: AgentLLMChatRequest) async throws -> AgentHostedValidatedResponse {
        guard let url = configuration.endpointURL else {
            throw AgentHostedAPIError.missingEndpoint
        }

        let hostedRequest = AgentHostedChatRequest(llmRequest: requestPayload)
        do {
            try AgentHostedAPIValidator.validateOutbound(hostedRequest)
        } catch {
            throw AgentHostedAPIError.validation(AgentSafetyRedactor.redact(String(describing: error)))
        }

        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        configuration.applyAuthentication(to: &request)
        request.httpBody = try encoder.encode(hostedRequest)

        do {
            let (data, response) = try await transport.perform(request)
            guard (200..<300).contains(response.statusCode) else {
                let body = String(data: data.prefix(512), encoding: .utf8).map(AgentSafetyRedactor.redact) ?? ""
                throw AgentHostedAPIError.httpStatus(response.statusCode, body)
            }
            let hostedResponse = try decoder.decode(AgentHostedChatResponse.self, from: data)
            return try AgentHostedResponseSanitizer.sanitize(hostedResponse)
        } catch let error as AgentHostedAPIError {
            throw error
        } catch let error as AgentHostedAPIValidationError {
            throw AgentHostedAPIError.validation(AgentSafetyRedactor.redact(String(describing: error)))
        } catch {
            throw AgentHostedAPIError.transport(AgentSafetyRedactor.redact(error.localizedDescription))
        }
    }
}
