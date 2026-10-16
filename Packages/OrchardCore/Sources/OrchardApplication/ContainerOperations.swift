import Foundation
import OrchardDomain

/// Runtime use cases shared by the desktop adapter and the HTTP service.
/// Presentation state and alerts belong to each client; failures are typed errors.
public actor ContainerOperations {
    private let backend: any ContainerBackend
    private var snapshots: [String: Container] = [:]
    private var busy: Set<String> = []

    public init(backend: any ContainerBackend) {
        self.backend = backend
    }

    public func health() async throws -> SystemHealthInfo {
        try await backend.ping()
    }

    public func list() async throws -> [Container] {
        let containers = try await backend.listContainers()
        for container in containers { snapshots[container.configuration.id] = container }
        return containers
    }

    public func start(_ id: String, maxRetries: Int = 3, retryDelay: TimeInterval = 1) async throws {
        try claim(id)
        defer { busy.remove(id) }
        let attempts = max(1, maxRetries)
        for attempt in 1...attempts {
            try Task.checkCancellation()
            do {
                try await backend.bootstrapAndStart(id: id)
                return
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                let classified = OrchardError.classifyStartError(error, id: id)
                switch classified {
                case .containerNotFound:
                    guard let snapshot = snapshots[id] else { throw OrchardError.recoveryFailed(id: id) }
                    do {
                        // createContainer already starts it; never bootstrap a second time.
                        try await backend.createContainer(recoverySpec(snapshot))
                        return
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        throw OrchardError.recoveryFailed(id: id)
                    }
                case .containerInTransition:
                    guard attempt < attempts else { throw classified }
                    if retryDelay.isFinite && retryDelay > 0 {
                        try await Task.sleep(for: .seconds(retryDelay))
                    }
                default:
                    throw classified
                }
            }
        }
    }

    public func stop(_ id: String) async throws {
        try claim(id)
        defer { busy.remove(id) }
        try await backend.stopContainer(id: id)
    }

    public func forceStop(_ id: String) async throws {
        try claim(id)
        defer { busy.remove(id) }
        try await backend.killContainer(id: id, signal: 9)
    }

    public func remove(_ id: String, force: Bool = false) async throws {
        try claim(id)
        defer { busy.remove(id) }
        try await backend.deleteContainer(id: id, force: force)
    }

    @discardableResult
    public func create(_ config: ContainerRunConfig) async throws -> String {
        let id = config.name.isEmpty ? String(UUID().uuidString.lowercased().prefix(12)) : config.name
        try claim(id)
        defer { busy.remove(id) }
        try await backend.createContainer(Self.createSpec(config, id: id))
        return id
    }

    private func claim(_ id: String) throws {
        guard busy.insert(id).inserted else { throw OrchardError.containerInTransition(id: id) }
    }

    private static func createSpec(_ config: ContainerRunConfig, id: String) -> ContainerCreateSpec {
        ContainerCreateSpec(
            id: id, imageRef: config.image,
            environment: config.environmentVariables.filter { !$0.key.isEmpty }.map { "\($0.key)=\($0.value)" },
            workingDirectory: config.workingDirectory,
            commandOverride: splitCommandLine(config.commandOverride),
            volumes: config.volumeMappings.filter { !$0.hostPath.isEmpty && !$0.containerPath.isEmpty }.map {
                .init(hostPath: $0.hostPath, containerPath: $0.containerPath, readonly: $0.readonly)
            },
            publishedPorts: config.portMappings.compactMap {
                guard let host = UInt16($0.hostPort), let container = UInt16($0.containerPort) else { return nil }
                return .init(hostPort: host, containerPort: container, transportProtocol: $0.transportProtocol)
            },
            dnsDomain: config.dnsDomain, networkName: config.network, autoRemove: config.removeAfterStop,
            cpus: max(1, config.cpus), memoryBytes: max(1_048_576, config.memoryBytes),
            labels: config.effectiveLabels
        )
    }

    private func recoverySpec(_ snapshot: Container) -> ContainerCreateSpec {
        let config = snapshot.configuration
        return ContainerCreateSpec(
            id: config.id, imageRef: config.image.reference,
            environment: config.initProcess.environment,
            workingDirectory: config.initProcess.workingDirectory, commandOverride: [],
            volumes: config.mounts.map {
                .init(hostPath: $0.source, containerPath: $0.destination, readonly: $0.options.contains("ro"))
            },
            publishedPorts: config.publishedPorts.compactMap {
                guard let host = UInt16(exactly: $0.hostPort), let container = UInt16(exactly: $0.containerPort) else { return nil }
                return .init(hostPort: host, containerPort: container, transportProtocol: $0.transportProtocol,
                             hostAddress: $0.hostAddress ?? "0.0.0.0")
            },
            dnsDomain: config.dns.domain ?? "",
            networkName: config.networkName ?? snapshot.networks.first?.network ?? "", autoRemove: false,
            cpus: max(1, config.resources.cpus), memoryBytes: max(1_048_576, UInt64(clamping: config.resources.memoryInBytes)),
            labels: config.labels
        )
    }
}
