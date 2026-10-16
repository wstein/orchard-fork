import Foundation

// MARK: - The container↔model bridge (pure)

/// Computes how a container reaches a model server running on the host, and the
/// environment a container needs to talk to it. Pure and package-free so it unit-tests in
/// isolation.
///
/// Load-bearing fact, verified against `container` 1.1.0: a workload's default route is
/// its network's vmnet gateway, and the host is reachable at that gateway address - *if*
/// the server binds all interfaces (`0.0.0.0`). A loopback-only (`127.0.0.1`) server is
/// refused from inside a container. So the bridge address is the network gateway, and it
/// is the provider's responsibility to actually listen on `0.0.0.0`.
public enum ModelBridge: Sendable {
    /// The base URL a container on a network with `gateway` uses to reach a host provider
    /// on `hostPort`. `gateway` is `ContainerNetwork.status.gateway` (the vmnet gateway,
    /// which is the host). OpenAI-style clients expect the `/v1` root; Ollama clients want
    /// the bare host.
    public static func containerBaseURL(gateway: String, hostPort: UInt16, api: ModelAPIStyle) -> String {
        let root = "http://\(ModelEndpoint.authority(gateway, port: hostPort))"
        switch api {
        case .openAI: return root + "/v1"
        case .ollama: return root
        }
    }

    /// As `containerBaseURL(gateway:hostPort:api:)`, but for a provider whose address the
    /// user has edited. Only a server on this Mac needs the gateway indirection; an
    /// endpoint pointed at another machine is already routable from inside a container, so
    /// its own host is used unchanged.
    public static func containerBaseURL(gateway: String, host: String, hostPort: UInt16, api: ModelAPIStyle) -> String {
        let reachable = ModelEndpoint.isLoopback(host) ? gateway : host
        return containerBaseURL(gateway: reachable, hostPort: hostPort, api: api)
    }

    /// Environment variables (as `key`/`value` pairs) to inject into a container so a
    /// standard client inside it reaches the host provider at `baseURL`. The placeholder
    /// key satisfies SDKs that require one even though a local server ignores it.
    public static func injectionEnvironment(baseURL: String, api: ModelAPIStyle, apiKey: String? = nil) -> [(key: String, value: String)] {
        switch api {
        case .openAI:
            return [
                ("OPENAI_BASE_URL", baseURL),
                // A keyed server (e.g. oMLX with auth enabled) needs the real key;
                // an open one just needs the placeholder SDKs insist on.
                ("OPENAI_API_KEY", apiKey ?? "not-needed"),
            ]
        case .ollama:
            return [
                ("OLLAMA_HOST", baseURL),
            ]
        }
    }
}

// MARK: - Backend protocol

/// The local-model discovery surface. Read-only in this slice: detect providers running on
/// the host and list the models they advertise. Mirrors `ContainerBackend`'s rule - 
/// app-owned types only, so mocks need no package imports.
public protocol ModelBackend: Sendable {
    /// Probe `endpoints` for running model providers and return those that responded.
    /// Only enabled endpoints are probed - a disabled one is not contacted at all, which
    /// is what makes the panel's off switch an actual off switch. `apiKeys` maps endpoint
    /// id -> stored API key, sent as a bearer token where present. Best-effort: never
    /// throws, since a missing provider is a normal state.
    func detectProviders(endpoints: [ModelEndpoint], apiKeys: [String: String]) async -> [ModelProvider]

    /// Send a chat conversation to a provider on `host:port` and return the assistant's
    /// reply. `messages` is the full history so the model has context. Used by the in-app
    /// tester; throws on transport or HTTP errors so the UI can surface them.
    func complete(host: String, port: UInt16, api: ModelAPIStyle, model: String, messages: [ChatMessage], apiKey: String?) async throws -> String
}

