import Foundation

// MARK: - Boundary value types

/// System health returned by `ping()`.
public struct SystemHealthInfo: Sendable {
    public let apiServerVersion: String

    public init(
        apiServerVersion: String
    ) {
        self.apiServerVersion = apiServerVersion
    }
}

/// A snapshot of image pull progress, folded from the client library's update
/// events into an app-owned type so views and tests never see TerminalProgress.
public struct ImagePullMetrics: Equatable, Sendable {
    public var bytesDownloaded: Int64 = 0
    public var totalBytes: Int64 = 0
    public var itemsCompleted: Int = 0
    public var totalItems: Int = 0
    /// What an "item" is for the current phase; the registry client reports "blobs".
    public var itemsName: String = "blobs"
    /// Phase label, e.g. "Fetching image".
    public var phase: String = ""

    public init(
        bytesDownloaded: Int64 = 0,
        totalBytes: Int64 = 0,
        itemsCompleted: Int = 0,
        totalItems: Int = 0,
        itemsName: String = "blobs",
        phase: String = ""
    ) {
        self.bytesDownloaded = bytesDownloaded
        self.totalBytes = totalBytes
        self.itemsCompleted = itemsCompleted
        self.totalItems = totalItems
        self.itemsName = itemsName
        self.phase = phase
    }
}

/// Everything needed to create and start a container, expressed in app-owned types so
/// the backend boundary never leaks the underlying client's model types to callers.
public struct ContainerCreateSpec: Sendable {
    public struct Volume: Sendable {
        public let hostPath: String
        public let containerPath: String
        public let readonly: Bool

        public init(
            hostPath: String,
            containerPath: String,
            readonly: Bool
        ) {
            self.hostPath = hostPath
            self.containerPath = containerPath
            self.readonly = readonly
        }
    }
    public struct Port: Sendable {
        public let hostPort: UInt16
        public let containerPort: UInt16
        public let transportProtocol: String
        /// The host interface to publish on. `0.0.0.0` unless something asked for one:
        /// a port published to `127.0.0.1` is deliberately not on the network, and
        /// widening it silently would be a security change nobody asked for.
        public var hostAddress: String = "0.0.0.0"

        public init(
            hostPort: UInt16,
            containerPort: UInt16,
            transportProtocol: String,
            hostAddress: String = "0.0.0.0"
        ) {
            self.hostPort = hostPort
            self.containerPort = containerPort
            self.transportProtocol = transportProtocol
            self.hostAddress = hostAddress
        }
    }

    public let id: String
    public let imageRef: String
    public let environment: [String]
    public let workingDirectory: String
    public let commandOverride: [String]
    public let volumes: [Volume]
    public let publishedPorts: [Port]
    public let dnsDomain: String
    public let networkName: String
    public let autoRemove: Bool
    /// CPU cores and memory (in bytes) allocated to the container's VM.
    public let cpus: Int
    public let memoryBytes: UInt64
    /// Key/value labels stamped on the container at creation - e.g. the sandbox marker
    /// that lets the Sandboxes view recognise a container Orchard wired to a model.
    public var labels: [String: String] = [:]

    public init(
        id: String,
        imageRef: String,
        environment: [String],
        workingDirectory: String,
        commandOverride: [String],
        volumes: [Volume],
        publishedPorts: [Port],
        dnsDomain: String,
        networkName: String,
        autoRemove: Bool,
        cpus: Int,
        memoryBytes: UInt64,
        labels: [String: String] = [:]
    ) {
        self.id = id
        self.imageRef = imageRef
        self.environment = environment
        self.workingDirectory = workingDirectory
        self.commandOverride = commandOverride
        self.volumes = volumes
        self.publishedPorts = publishedPorts
        self.dnsDomain = dnsDomain
        self.networkName = networkName
        self.autoRemove = autoRemove
        self.cpus = cpus
        self.memoryBytes = memoryBytes
        self.labels = labels
    }
}

/// Combine an image's entrypoint and cmd with a user command override into the final
/// process argument vector. Override replaces cmd; entrypoint is always prefixed.
public func resolveProcessArguments(imageEntrypoint: [String]?, imageCmd: [String]?, override: [String]) -> [String] {
    var processArgs: [String] = []
    if let entrypoint = imageEntrypoint, !entrypoint.isEmpty {
        processArgs = entrypoint
    }
    if !override.isEmpty {
        if processArgs.isEmpty {
            processArgs = override
        } else {
            processArgs.append(contentsOf: override)
        }
    } else if let cmd = imageCmd, !cmd.isEmpty, processArgs.isEmpty || (imageEntrypoint != nil) {
        processArgs.append(contentsOf: cmd)
    }
    return processArgs
}

// MARK: - Machine backing-container filtering

/// A container machine is, under the hood, a container tagged with this label
/// (`com.apple.container.plugin` = `machine`). The raw list API returns these backing
/// containers; the `container` CLI hides them client-side and so does Orchard, keeping
/// them out of the container list where their actions would be meaningless.
///
/// The key mirrors upstream `ResourceLabelKeys.plugin`; it is inlined here so the
/// predicate stays free of package types and unit-testable in isolation.
public enum MachineBackingContainer: Sendable {
    public static let pluginLabelKey = "com.apple.container.plugin"
    public static let machinePluginValue = "machine"

    /// True when a container's labels mark it as the backing container of a machine.
    public static func isMachine(labels: [String: String]) -> Bool {
        labels[pluginLabelKey] == machinePluginValue
    }
}

// MARK: - Backend protocol

/// The container runtime surface, expressed entirely in app domain models. Mocks
/// conforming to this need no client-package imports.
public protocol ContainerBackend: Sendable {
    func listContainers() async throws -> [Container]
    func stopContainer(id: String) async throws
    func killContainer(id: String, signal: Int32) async throws
    func deleteContainer(id: String, force: Bool) async throws
    func bootstrapAndStart(id: String) async throws
    func containerLogs(id: String) async throws -> [FileHandle]
    /// Export the container's filesystem as a tar archive at `destination`,
    /// replacing any existing file there.
    func exportContainer(id: String, to destination: URL) async throws
    /// Trim the free blocks in a running container's root filesystem and volumes so
    /// the host-side disk images shrink back to what the container actually holds.
    func cleanContainer(id: String) async throws
    func stats(id: String) async throws -> ContainerStats
    func createContainer(_ spec: ContainerCreateSpec) async throws
    func listImages() async throws -> [ContainerImage]
    func pullImage(reference: String, onProgress: (@Sendable (ImagePullMetrics) -> Void)?) async throws
    func deleteImage(reference: String) async throws
    func inspectImage(reference: String) async throws -> ImageInspection
    func listNetworks() async throws -> [ContainerNetwork]
    func createNetwork(name: String, subnet: String?, labels: [String: String]) async throws
    func deleteNetwork(id: String) async throws
    func ping() async throws -> SystemHealthInfo
    func diskUsage() async throws -> SystemDiskUsage
}

// MARK: - Error mapping

public func mapContainerError(_ error: Error) -> Error {
    isContainerServiceUnavailable(error) ? OrchardError.xpcUnavailable : error
}

/// The apple/container release Orchard's client libraries are built against. Keep in
/// sync with the container package pin in project.pbxproj when bumping.
public let supportedContainerVersion = "1.4.1"

/// A ping reply the linked client cannot decode means the installed daemon speaks a
/// different protocol revision than the client libraries Orchard links.
public func isContainerVersionMismatch(_ error: Error) -> Bool {
    let message = error.localizedDescription.lowercased()
    return message.contains("failed to decode") && message.contains("health check")
}

public func isContainerServiceUnavailable(_ error: Error) -> Bool {
    let message = error.localizedDescription.lowercased()
    return message.contains("connection invalid")
        || message.contains("connection was invalid")
        || message.contains("connection interrupted")
        || message.contains("xpc connection")
        || message.contains("couldn’t communicate")
        || message.contains("couldn't communicate")
        || message.contains("could not communicate")
        || message.contains("service could not")
        || message.contains("no such xpc")
}

