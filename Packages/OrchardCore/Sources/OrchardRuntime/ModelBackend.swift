import Foundation
import OrchardDomain

// MARK: - Live implementation

/// Refuses every HTTP redirect. Probes aim at conventional ports, which are routinely
/// owned by something other than a model server - an ordinary dev server on 8080 will
/// happily 301 the probe onto another port or host. Following that spends the 1.5s probe
/// deadline on an unrelated endpoint and, when it expires, abandons a half-finished
/// connection there. A real provider answers 200 directly, so a redirect means no more
/// than "not a provider". Stateless, hence safe to share across concurrent probes.
private final class ProbeRedirectBlocker: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest
    ) async -> URLRequest? {
        nil
    }
}

private let probeRedirectBlocker = ProbeRedirectBlocker()

/// `ModelBackend` that discovers providers by probing their conventional loopback ports
/// over HTTP. An unreachable port simply means "that provider isn't running."
public struct LiveModelBackend: ModelBackend {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func detectProviders(endpoints: [ModelEndpoint], apiKeys: [String: String]) async -> [ModelProvider] {
        let session = self.session
        return await withTaskGroup(of: ModelProvider?.self) { group in
            for endpoint in endpoints where endpoint.isEnabled {
                let key = apiKeys[endpoint.id]
                group.addTask { await Self.probe(endpoint, session: session, apiKey: key) }
            }
            var found: [ModelProvider] = []
            for await result in group {
                if let result { found.append(result) }
            }
            return found.sorted { $0.id < $1.id }
        }
    }

    /// Probe one endpoint. Non-private so the redirect and classification behaviour is
    /// testable against a stub transport.
    static func probe(_ endpoint: ModelEndpoint, session: URLSession, apiKey: String?) async -> ModelProvider? {
        guard let url = URL(string: endpoint.probeBaseURL + endpoint.listPath) else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.5
        if let apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        guard let (data, response) = try? await session.data(for: request, delegate: probeRedirectBlocker),
              let http = response as? HTTPURLResponse else {
            return nil
        }
        return provider(from: http.statusCode, data: data, endpoint: endpoint)
    }

    /// Classify a probe response. 200 is a live provider; 401/403 is a live server that
    /// wants an API key (e.g. oMLX generates one at setup) - surfaced as locked so the
    /// user can supply the key, rather than being invisible. Anything else is not a
    /// provider. Pure, so the classification is unit-testable.
    static func provider(from status: Int, data: Data, endpoint: ModelEndpoint) -> ModelProvider? {
        switch status {
        case 200:
            return ModelProvider(
                kind: refineKind(endpoint.kind, data: data, api: endpoint.api),
                host: endpoint.host,
                port: endpoint.port,
                api: endpoint.api,
                models: parseModels(data, api: endpoint.api),
                endpointID: endpoint.id
            )
        case 401, 403:
            return ModelProvider(
                kind: endpoint.kind,
                host: endpoint.host,
                port: endpoint.port,
                api: endpoint.api,
                models: [],
                requiresAPIKey: true,
                endpointID: endpoint.id
            )
        default:
            return nil
        }
    }

    /// oMLX serves the same OpenAI-style API on the same conventional port (8000) as
    /// `mlx_lm.server`, so the port alone can't tell them apart. Its models listing
    /// stamps `"owned_by": "omlx"` on every model - that's the fingerprint used here.
    static func refineKind(_ kind: ModelProvider.Kind, data: Data, api: ModelAPIStyle) -> ModelProvider.Kind {
        guard api == .openAI,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = obj["data"] as? [[String: Any]] else {
            return kind
        }
        if models.contains(where: { ($0["owned_by"] as? String) == "omlx" }) {
            return .omlx
        }
        return kind
    }

    public func complete(host: String, port: UInt16, api: ModelAPIStyle, model: String, messages: [ChatMessage], apiKey: String?) async throws -> String {
        let root = "http://\(ModelEndpoint.authority(ModelEndpoint.dialHost(host), port: port))"
        let wireMessages = messages.map { ["role": $0.role.rawValue, "content": $0.content] }
        let path: String
        let body: [String: Any]
        switch api {
        case .openAI:
            path = "/v1/chat/completions"
            body = [
                "model": model,
                "messages": wireMessages,
                "max_tokens": 512,
                "temperature": 0.7,
            ]
        case .ollama:
            path = "/api/chat"
            body = [
                "model": model,
                "messages": wireMessages,
                "stream": false,
            ]
        }

        guard let url = URL(string: root + path) else {
            throw OrchardError.generic("Invalid model endpoint.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 120

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw OrchardError.generic("No response from the model server.")
        }
        guard http.statusCode == 200 else {
            let detail = String(data: data, encoding: .utf8).map { String($0.prefix(300)) } ?? ""
            throw OrchardError.generic("Model server returned HTTP \(http.statusCode). \(detail)")
        }
        return try Self.parseCompletion(data, api: api)
    }

    /// Extract the assistant's reply text from a chat-completion response.
    static func parseCompletion(_ data: Data, api: ModelAPIStyle) throws -> String {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw OrchardError.generic("Could not read the model server's response.")
        }
        switch api {
        case .openAI:
            let choices = obj["choices"] as? [[String: Any]]
            let message = choices?.first?["message"] as? [String: Any]
            if let content = message?["content"] as? String { return content }
        case .ollama:
            let message = obj["message"] as? [String: Any]
            if let content = message?["content"] as? String { return content }
        }
        throw OrchardError.generic("The model server returned an unexpected response shape.")
    }

    /// Extract model ids from a provider's listing response. Both shapes are flat JSON.
    static func parseModels(_ data: Data, api: ModelAPIStyle) -> [String] {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        switch api {
        case .openAI:
            // { "data": [ { "id": "..." }, ... ] }
            let arr = obj["data"] as? [[String: Any]] ?? []
            return arr.compactMap { $0["id"] as? String }
        case .ollama:
            // { "models": [ { "name": "..." }, ... ] }
            let arr = obj["models"] as? [[String: Any]] ?? []
            return arr.compactMap { $0["name"] as? String }
        }
    }
}
