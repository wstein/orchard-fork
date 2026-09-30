import Foundation

// MARK: - Container Models

public struct Container: Codable, Equatable, Sendable {
    public let status: String
    public let configuration: ContainerConfiguration
    public let networks: [Network]

    enum CodingKeys: String, CodingKey {
        case status
        case configuration
        case networks
    }

    public init(
        status: String,
        configuration: ContainerConfiguration,
        networks: [Network]
    ) {
        self.status = status
        self.configuration = configuration
        self.networks = networks
    }
}

public struct ContainerConfiguration: Codable, Equatable, Sendable {
    public let id: String
    public let hostname: String?
    /// The network the container is configured to join. Unlike `Container.networks`, which
    /// is the live attachment and empty while the container is stopped, this survives a stop,
    /// so a stopped container still says which network it belongs to.
    public let networkName: String?
    public let runtimeHandler: String
    public let initProcess: initProcess
    public let mounts: [Mount]
    public let platform: Platform
    public let image: Image
    public let rosetta: Bool
    public let dns: DNS
    public let resources: Resources
    public let labels: [String: String]
    public let publishedPorts: [PublishedPort]
    public let publishedSockets: [String]?
    public let ssh: Bool?
    public let virtualization: Bool?
    public let sysctls: [String: String]

    enum CodingKeys: String, CodingKey {
        case id
        case hostname
        case networkName
        case runtimeHandler
        case initProcess
        case mounts
        case platform
        case image
        case rosetta
        case dns
        case resources
        case labels
        case publishedPorts
        case publishedSockets
        case ssh
        case virtualization
        case sysctls
    }

    public init(
        id: String,
        hostname: String? = nil,
        networkName: String? = nil,
        runtimeHandler: String,
        initProcess: initProcess,
        mounts: [Mount],
        platform: Platform,
        image: Image,
        rosetta: Bool,
        dns: DNS,
        resources: Resources,
        labels: [String: String],
        publishedPorts: [PublishedPort],
        publishedSockets: [String]? = nil,
        ssh: Bool? = nil,
        virtualization: Bool? = nil,
        sysctls: [String: String]
    ) {
        self.id = id
        self.hostname = hostname
        self.networkName = networkName
        self.runtimeHandler = runtimeHandler
        self.initProcess = initProcess
        self.mounts = mounts
        self.platform = platform
        self.image = image
        self.rosetta = rosetta
        self.dns = dns
        self.resources = resources
        self.labels = labels
        self.publishedPorts = publishedPorts
        self.publishedSockets = publishedSockets
        self.ssh = ssh
        self.virtualization = virtualization
        self.sysctls = sysctls
    }
}

public struct Mount: Codable, Equatable, Sendable {
    public let type: MountType
    public let source: String
    public let options: [String]
    public let destination: String

    enum CodingKeys: String, CodingKey {
        case type
        case source
        case options
        case destination
    }

    public init(
        type: MountType,
        source: String,
        options: [String],
        destination: String
    ) {
        self.type = type
        self.source = source
        self.options = options
        self.destination = destination
    }
}

public struct MountType: Codable, Equatable, Sendable {
    public let tmpfs: Tmpfs?
    public let virtiofs: Virtiofs?

    enum CodingKeys: String, CodingKey {
        case tmpfs
        case virtiofs
    }

    public init(
        tmpfs: Tmpfs? = nil,
        virtiofs: Virtiofs? = nil
    ) {
        self.tmpfs = tmpfs
        self.virtiofs = virtiofs
    }
}

public struct Tmpfs: Codable, Equatable, Sendable {
    public init() {}
}

public struct Virtiofs: Codable, Equatable, Sendable {
    public init() {}
}

public struct initProcess: Codable, Equatable, Sendable {
    public let terminal: Bool
    public let environment: [String]
    public let workingDirectory: String
    public let arguments: [String]
    public let executable: String
    public let user: User
    public let rlimits: [String]
    public let supplementalGroups: [Int]

    enum CodingKeys: String, CodingKey {
        case terminal
        case environment
        case workingDirectory
        case arguments
        case executable
        case user
        case rlimits
        case supplementalGroups
    }

    public init(
        terminal: Bool,
        environment: [String],
        workingDirectory: String,
        arguments: [String],
        executable: String,
        user: User,
        rlimits: [String],
        supplementalGroups: [Int]
    ) {
        self.terminal = terminal
        self.environment = environment
        self.workingDirectory = workingDirectory
        self.arguments = arguments
        self.executable = executable
        self.user = user
        self.rlimits = rlimits
        self.supplementalGroups = supplementalGroups
    }
}

public struct User: Codable, Equatable, Sendable {
    public let id: UserID?
    public let raw: UserRaw?

    enum CodingKeys: String, CodingKey {
        case id
        case raw
    }

    public init(
        id: UserID? = nil,
        raw: UserRaw? = nil
    ) {
        self.id = id
        self.raw = raw
    }
}

public struct UserRaw: Codable, Equatable, Sendable {
    public let userString: String

    enum CodingKeys: String, CodingKey {
        case userString
    }

    public init(
        userString: String
    ) {
        self.userString = userString
    }
}

public struct UserID: Codable, Equatable, Sendable {
    public let gid: Int
    public let uid: Int

    enum CodingKeys: String, CodingKey {
        case gid
        case uid
    }

    public init(
        gid: Int,
        uid: Int
    ) {
        self.gid = gid
        self.uid = uid
    }
}

public struct Network: Codable, Equatable, Sendable {
    public var gateway: String
    public var hostname: String
    public var network: String
    public var address: String

    enum CodingKeys: String, CodingKey {
        case gateway = "ipv4Gateway"
        case hostname
        case network
        case address = "ipv4Address"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        gateway = try container.decodeIfPresent(String.self, forKey: .gateway) ?? ""
        hostname = try container.decodeIfPresent(String.self, forKey: .hostname) ?? ""
        network = try container.decodeIfPresent(String.self, forKey: .network) ?? ""
        address = try container.decodeIfPresent(String.self, forKey: .address) ?? ""
    }
    
    public init(gateway: String = "", hostname: String = "", network: String = "", address: String = "") {
        self.gateway = gateway
        self.hostname = hostname
        self.network = network
        self.address = address
    }
}

public struct Image: Codable, Equatable, Sendable {
    public let descriptor: ImageDescriptor
    public let reference: String

    enum CodingKeys: String, CodingKey {
        case descriptor
        case reference
    }

    public init(
        descriptor: ImageDescriptor,
        reference: String
    ) {
        self.descriptor = descriptor
        self.reference = reference
    }
}

public struct ImageDescriptor: Codable, Equatable, Sendable {
    public let mediaType: String
    public let digest: String
    public let size: Int

    enum CodingKeys: String, CodingKey {
        case mediaType
        case digest
        case size
    }

    public init(
        mediaType: String,
        digest: String,
        size: Int
    ) {
        self.mediaType = mediaType
        self.digest = digest
        self.size = size
    }
}

public struct DNS: Codable, Equatable, Sendable {
    public let nameservers: [String]
    public let searchDomains: [String]
    public let options: [String]
    public let domain: String?

    enum CodingKeys: String, CodingKey {
        case nameservers
        case searchDomains
        case options
        case domain
    }

    public init(
        nameservers: [String],
        searchDomains: [String],
        options: [String],
        domain: String? = nil
    ) {
        self.nameservers = nameservers
        self.searchDomains = searchDomains
        self.options = options
        self.domain = domain
    }
}

public struct Resources: Codable, Equatable, Sendable {
    public let cpus: Int
    public let memoryInBytes: Int

    enum CodingKeys: String, CodingKey {
        case cpus
        case memoryInBytes
    }

    public init(
        cpus: Int,
        memoryInBytes: Int
    ) {
        self.cpus = cpus
        self.memoryInBytes = memoryInBytes
    }
}

public struct Platform: Codable, Equatable, Sendable {
    public let os: String
    public let architecture: String
    public let variant: String?

    enum CodingKeys: String, CodingKey {
        case os
        case architecture
        case variant
    }

    public init(
        os: String,
        architecture: String,
        variant: String? = nil
    ) {
        self.os = os
        self.architecture = architecture
        self.variant = variant
    }
}

// MARK: - Machine Models

/// A container machine - a persistent, stateful lightweight Linux VM - expressed entirely
/// in app-owned types so the machine XPC client's model types never leak past the backend.
///
/// `isDefault` is resolved by `MachineService` from the machine API's separate `getDefault()`
/// call; the snapshot itself does not carry it. `ipAddress`, `containerId`, and `startedDate`
/// are only populated while a machine is running (verified in the M0 spike).
public struct Machine: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let status: String
    public let isDefault: Bool
    public let cpus: Int
    public let memoryBytes: Int
    public let diskSizeBytes: Int?
    /// Home directory mount mode: `rw`, `ro`, or `none`.
    public let homeMount: String
    public let virtualization: Bool
    public let kernelPath: String?
    public let imageReference: String
    public let platform: Platform
    public let ipAddress: String?
    public let containerId: String?
    public let createdDate: Date?
    public let startedDate: Date?
    public let initialized: Bool
    public let userSetup: MachineUserSetup?

    public var isRunning: Bool { status == "running" }
    public var isStopped: Bool { status == "stopped" }

    public init(
        id: String,
        status: String,
        isDefault: Bool,
        cpus: Int,
        memoryBytes: Int,
        diskSizeBytes: Int? = nil,
        homeMount: String,
        virtualization: Bool,
        kernelPath: String? = nil,
        imageReference: String,
        platform: Platform,
        ipAddress: String? = nil,
        containerId: String? = nil,
        createdDate: Date? = nil,
        startedDate: Date? = nil,
        initialized: Bool,
        userSetup: MachineUserSetup? = nil
    ) {
        self.id = id
        self.status = status
        self.isDefault = isDefault
        self.cpus = cpus
        self.memoryBytes = memoryBytes
        self.diskSizeBytes = diskSizeBytes
        self.homeMount = homeMount
        self.virtualization = virtualization
        self.kernelPath = kernelPath
        self.imageReference = imageReference
        self.platform = platform
        self.ipAddress = ipAddress
        self.containerId = containerId
        self.createdDate = createdDate
        self.startedDate = startedDate
        self.initialized = initialized
        self.userSetup = userSetup
    }
}

/// The host user mapped into a machine at first-boot provisioning.
public struct MachineUserSetup: Codable, Equatable, Sendable {
    public let username: String
    public let uid: Int
    public let gid: Int

    public init(
        username: String,
        uid: Int,
        gid: Int
    ) {
        self.username = username
        self.uid = uid
        self.gid = gid
    }
}

// MARK: - Local model providers (the container↔model bridge)

/// The wire API a model provider speaks. Decides which environment variables a container
/// needs so an in-container client reaches the host provider.
public enum ModelAPIStyle: String, Codable, Sendable {
    case openAI
    case ollama
}

/// An address Orchard probes for a model server. Seeded from the conventional defaults the
/// first time the panel runs, then owned by the user: the host and port are editable, and
/// any endpoint can be switched off so discovery stops touching it at all (#110). A
/// detected provider is simply an endpoint that answered, so the two share an identity.
public struct ModelEndpoint: Codable, Equatable, Identifiable, Sendable {
    /// Stable across edits. The host and port are an endpoint's *contents*, not its
    /// identity, so re-pointing one at a different port keeps its stored key and its place
    /// in the list. Built-ins carry a fixed slug so a defaults restore can match them up.
    public let id: String
    public var kind: ModelProvider.Kind
    public var host: String
    public var port: UInt16
    public var api: ModelAPIStyle
    /// False stops discovery probing this address entirely: the escape hatch for a server
    /// that rejects every probe and would otherwise be polled for as long as Orchard runs.
    public var isEnabled: Bool

    public init(
        id: String = UUID().uuidString,
        kind: ModelProvider.Kind,
        host: String = ModelEndpoint.defaultHost,
        port: UInt16,
        api: ModelAPIStyle,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.kind = kind
        self.host = host
        self.port = port
        self.api = api
        self.isEnabled = isEnabled
    }

    public static let defaultHost = "127.0.0.1"

    /// Addresses that name this Mac. A server here is reached from a container through the
    /// network gateway; anything else is already routable as written.
    public static let loopbackHosts: Set<String> = ["127.0.0.1", "localhost", "::1", "0.0.0.0"]

    public static func isLoopback(_ host: String) -> Bool {
        loopbackHosts.contains(host.lowercased())
    }

    /// The listing endpoint used both to confirm liveness and to enumerate models. Derived
    /// from the wire API rather than stored, so editing an endpoint can't leave the path
    /// and the API style disagreeing.
    public var listPath: String {
        switch api {
        case .openAI: return "/v1/models"
        case .ollama: return "/api/tags"
        }
    }

    /// `host:port` as a URL authority. An IPv6 literal has to be bracketed or its own
    /// colons read as the port separator: `http://::1:8080` doesn't parse at all, so an
    /// endpoint addressed that way would be skipped by every probe without a word.
    public static func authority(_ host: String, port: UInt16) -> String {
        host.contains(":") ? "[\(host)]:\(port)" : "\(host):\(port)"
    }

    /// The base URL as seen from this Mac, as configured.
    public var hostBaseURL: String { "http://\(Self.authority(host, port: port))" }

    /// The base URL a client actually dials. `0.0.0.0` is a bind address, not a
    /// destination - it means "every interface on this Mac" - so a client asking for it
    /// goes to loopback instead.
    public var probeBaseURL: String { "http://\(Self.authority(Self.dialHost(host), port: port))" }

    public static func dialHost(_ host: String) -> String {
        host == "0.0.0.0" ? "127.0.0.1" : host
    }

    /// Keychain account for this endpoint's API key. Derived from the address rather than
    /// the id so a key survives the endpoint list being reseeded.
    public var secretAccount: String { "\(host):\(port)" }

    public var isLoopback: Bool { Self.isLoopback(host) }

    /// ⚠ Ports are conventional defaults - revisit if they prove unreliable in the field.
    public static let builtIns: [ModelEndpoint] = [
        ModelEndpoint(id: "builtin.ollama.11434", kind: .ollama, port: 11434, api: .ollama),
        ModelEndpoint(id: "builtin.lmstudio.1234", kind: .lmStudio, port: 1234, api: .openAI),
        ModelEndpoint(id: "builtin.mlx.8080", kind: .mlxServer, port: 8080, api: .openAI),
        ModelEndpoint(id: "builtin.mlx.8000", kind: .mlxServer, port: 8000, api: .openAI),
    ]

    /// The address this endpoint shipped with, when it is a built-in - the target for
    /// "restore the default". Nil for anything the user added.
    public var builtInDefault: ModelEndpoint? { Self.builtIns.first { $0.id == id } }

    /// Whether the user has moved this endpoint off the address it shipped with.
    public var isEdited: Bool {
        guard let original = builtInDefault else { return false }
        return original.host != host || original.port != port || original.api != api
    }

    /// Whether this endpoint earns a row of its own while nothing is answering on it. A
    /// built-in sitting on its shipped address does not: "you aren't running LM Studio"
    /// is not a thing to report, and four dead rows would be the whole panel on an idle
    /// Mac. One the user moved, or added, does - otherwise a mistyped address takes the
    /// endpoint out of the list and leaves nowhere to correct it from.
    public var isUserConfigured: Bool { isEdited || builtInDefault == nil }

    public var displayName: String { kind.displayName }
}

/// One turn in a chat conversation, in the shape the OpenAI/Ollama chat APIs expect.
public struct ChatMessage: Identifiable, Equatable, Sendable {
    public enum Role: String, Sendable {
        case user
        case assistant
    }

    public let id = UUID()
    public let role: Role
    public var content: String

    public init(
        role: Role,
        content: String
    ) {
        self.role = role
        self.content = content
    }
}

/// A local inference provider discovered running on the host - Ollama, LM Studio, an MLX
/// server, and so on. Orchard *manages and bridges* providers; it does not run inference
/// itself. Detected read-only in this first slice.
public struct ModelProvider: Identifiable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable, CaseIterable {
        case ollama
        case lmStudio
        case mlxServer
        case omlx
        case custom

        public var displayName: String {
            switch self {
            case .ollama: return "Ollama"
            case .lmStudio: return "LM Studio"
            case .mlxServer: return "MLX Server"
            case .omlx: return "oMLX"
            case .custom: return "Custom"
            }
        }
    }

    public let kind: Kind
    /// The host the provider listens on, as configured on its endpoint. Loopback unless
    /// the user has re-pointed it.
    public let host: String
    /// The port the provider listens on, as seen from this Mac.
    public let port: UInt16
    /// The wire API the provider speaks.
    public let api: ModelAPIStyle
    /// Model identifiers the provider advertises, when it exposes a listing endpoint.
    public var models: [String]
    /// The server answered the probe with 401/403: it's running but wants an API key
    /// before it will list models or serve completions.
    public var requiresAPIKey: Bool = false
    /// The configured `ModelEndpoint` this provider answered on, and the provider's own
    /// identity. Endpoint-derived rather than address-derived so editing an endpoint's
    /// host or port doesn't read as a different provider to identity-based UI state, and
    /// so `kind` being refined from the models listing (e.g. oMLX) can't flap it either.
    public let endpointID: String

    public init(
        kind: Kind,
        host: String = ModelEndpoint.defaultHost,
        port: UInt16,
        api: ModelAPIStyle,
        models: [String],
        requiresAPIKey: Bool = false,
        endpointID: String? = nil
    ) {
        self.kind = kind
        self.host = host
        self.port = port
        self.api = api
        self.models = models
        self.requiresAPIKey = requiresAPIKey
        // Providers built outside the configured list (fixtures, tests) fall back to the
        // address, which is unique for as long as they exist.
        self.endpointID = endpointID ?? "\(api.rawValue):\(host):\(port)"
    }

    public var id: String { endpointID }

    /// The base URL reachable *from this Mac* (e.g. `http://127.0.0.1:11434`). Distinct
    /// from the container-reachable URL, which for a loopback server goes through the
    /// network gateway - see `ModelBridge`.
    public var hostBaseURL: String { "http://\(ModelEndpoint.authority(host, port: port))" }

    /// Whether a container needs the gateway indirection to reach this provider.
    public var isLoopback: Bool { ModelEndpoint.isLoopback(host) }
}

/// A model server Orchard started and supervises (as opposed to a `ModelProvider`, which is
/// any server merely detected running). Carries the config it was launched with plus its
/// live lifecycle state.
public struct ManagedModelServer: Identifiable, Equatable, Sendable {
    public enum Status: String, Sendable {
        case running
        case failed
    }

    /// Stable identity: one server per model+port. Also the log-file key.
    public let id: String
    public let model: String
    public let host: String
    public let port: UInt16
    public var status: Status
    /// Absolute path to the captured stdout/stderr log.
    public let logPath: String

    /// mlx_lm.server speaks the OpenAI wire API.
    public var api: ModelAPIStyle { .openAI }
    /// Whether the server is bound to all interfaces, so containers can reach it.
    public var reachableFromContainers: Bool { host == "0.0.0.0" }

    public init(
        id: String,
        model: String,
        host: String,
        port: UInt16,
        status: Status,
        logPath: String
    ) {
        self.id = id
        self.model = model
        self.host = host
        self.port = port
        self.status = status
        self.logPath = logPath
    }
}

public struct PublishedPort: Codable, Equatable, Sendable {
    public let hostPort: Int
    public let containerPort: Int
    public let transportProtocol: String
    public let hostAddress: String?

    /// Stable identity for `ForEach`: `containerPort` alone repeats when the same port is
    /// published over more than one transport (e.g. tcp + udp), which collapses rows.
    public var uniqueID: String {
        "\(hostAddress ?? "")|\(hostPort)|\(containerPort)|\(transportProtocol)"
    }

    enum CodingKeys: String, CodingKey {
        case hostPort
        case containerPort
        case transportProtocol = "proto"
        case hostAddress
    }

    public init(
        hostPort: Int,
        containerPort: Int,
        transportProtocol: String,
        hostAddress: String? = nil
    ) {
        self.hostPort = hostPort
        self.containerPort = containerPort
        self.transportProtocol = transportProtocol
        self.hostAddress = hostAddress
    }
}

// MARK: - Container Image Models

public struct ContainerImage: Codable, Equatable, Identifiable, Sendable {
    public let descriptor: ContainerImageDescriptor
    public let reference: String

    public var id: String { reference }

    enum CodingKeys: String, CodingKey {
        case descriptor
        case reference
    }

    public init(
        descriptor: ContainerImageDescriptor,
        reference: String
    ) {
        self.descriptor = descriptor
        self.reference = reference
    }
}

public struct ContainerImageDescriptor: Codable, Equatable, Sendable {
    public let digest: String
    public let mediaType: String
    public let size: Int
    public let annotations: [String: String]?

    enum CodingKeys: String, CodingKey {
        case digest
        case mediaType
        case size
        case annotations
    }

    public init(
        digest: String,
        mediaType: String,
        size: Int,
        annotations: [String: String]? = nil
    ) {
        self.digest = digest
        self.mediaType = mediaType
        self.size = size
        self.annotations = annotations
    }
}

// MARK: - Image Inspection Models

public struct ImageInspection: Sendable {
    public let name: String
    public let digest: String
    public let mediaType: String
    public let size: Int64
    public let variants: [Variant]

    public struct Variant: Sendable {
        public let platform: String
        public let size: Int64
        public let entrypoint: [String]?
        public let cmd: [String]?
        public let env: [String]?
        public let workingDir: String?
        public let user: String?
        public let exposedPorts: [String]?
        public let volumes: [String]?

        public init(
            platform: String,
            size: Int64,
            entrypoint: [String]? = nil,
            cmd: [String]? = nil,
            env: [String]? = nil,
            workingDir: String? = nil,
            user: String? = nil,
            exposedPorts: [String]? = nil,
            volumes: [String]? = nil
        ) {
            self.platform = platform
            self.size = size
            self.entrypoint = entrypoint
            self.cmd = cmd
            self.env = env
            self.workingDir = workingDir
            self.user = user
            self.exposedPorts = exposedPorts
            self.volumes = volumes
        }
    }

    public init(
        name: String,
        digest: String,
        mediaType: String,
        size: Int64,
        variants: [Variant]
    ) {
        self.name = name
        self.digest = digest
        self.mediaType = mediaType
        self.size = size
        self.variants = variants
    }
}

// MARK: - Mount Models

public struct ContainerMount: Identifiable, Equatable, Sendable {
    public let id: String
    public let mount: Mount
    public let containerIds: [String]

    public init(mount: Mount, containerIds: [String]) {
        self.mount = mount
        self.containerIds = containerIds
        // Create a unique ID based on source and destination
        self.id = "\(mount.source)->\(mount.destination)"
    }

    public var mountType: String {
        if mount.type.virtiofs != nil {
            return "VirtioFS"
        } else if mount.type.tmpfs != nil {
            return "tmpfs"
        } else {
            return "Unknown"
        }
    }

    public var optionsString: String {
        mount.options.joined(separator: ", ")
    }
}

// MARK: - DNS Models

public struct DNSDomain: Codable, Equatable, Identifiable, Sendable {
    public let domain: String
    public let isDefault: Bool

    public var id: String { domain }

    public init(domain: String, isDefault: Bool = false) {
        self.domain = domain
        self.isDefault = isDefault
    }
}

// MARK: - Kernel Models

public struct KernelConfig: Codable, Equatable, Sendable {
    public let binary: String?
    public let tar: String?
    public let arch: KernelArch
    public let isRecommended: Bool

    public init(binary: String? = nil, tar: String? = nil, arch: KernelArch = .arm64, isRecommended: Bool = false) {
        self.binary = binary
        self.tar = tar
        self.arch = arch
        self.isRecommended = isRecommended
    }
}

public enum KernelArch: String, CaseIterable, Codable, Sendable {
    case amd64 = "amd64"
    case arm64 = "arm64"

    public var displayName: String {
        switch self {
        case .amd64:
            return "Intel (x86_64)"
        case .arm64:
            return "Apple Silicon (ARM64)"
        }
    }
}



// MARK: - Builder Models

public struct Builder: Codable, Equatable, Sendable {
    public let status: String
    public let configuration: BuilderConfiguration
    public let networks: [Network]

    enum CodingKeys: String, CodingKey {
        case status
        case configuration
        case networks
    }

    public init(
        status: String,
        configuration: BuilderConfiguration,
        networks: [Network]
    ) {
        self.status = status
        self.configuration = configuration
        self.networks = networks
    }
}

public struct BuilderConfiguration: Codable, Equatable, Sendable {
    public let id: String
    public let image: Image
    public let initProcess: initProcess
    public let labels: [String: String]
    public let mounts: [Mount]
    public let networks: [BuilderNetwork]
    public let platform: Platform
    public let resources: Resources
    public let rosetta: Bool
    public let runtimeHandler: String
    public let sysctls: [String: String]
    public let dns: DNS

    enum CodingKeys: String, CodingKey {
        case id
        case image
        case initProcess
        case labels
        case mounts
        case networks
        case platform
        case resources
        case rosetta
        case runtimeHandler
        case sysctls
        case dns
    }

    public init(
        id: String,
        image: Image,
        initProcess: initProcess,
        labels: [String: String],
        mounts: [Mount],
        networks: [BuilderNetwork],
        platform: Platform,
        resources: Resources,
        rosetta: Bool,
        runtimeHandler: String,
        sysctls: [String: String],
        dns: DNS
    ) {
        self.id = id
        self.image = image
        self.initProcess = initProcess
        self.labels = labels
        self.mounts = mounts
        self.networks = networks
        self.platform = platform
        self.resources = resources
        self.rosetta = rosetta
        self.runtimeHandler = runtimeHandler
        self.sysctls = sysctls
        self.dns = dns
    }
}

public struct BuilderNetwork: Codable, Equatable, Sendable {
    // Builder networks may have different structure than container networks
    // Making fields optional to handle variations in the JSON
    public let gateway: String?
    public let hostname: String?
    public let network: String?
    public let address: String?
    public let name: String?
    public let id: String?

    enum CodingKeys: String, CodingKey {
        case gateway
        case hostname
        case network
        case address
        case name
        case id
    }

    public init(
        gateway: String? = nil,
        hostname: String? = nil,
        network: String? = nil,
        address: String? = nil,
        name: String? = nil,
        id: String? = nil
    ) {
        self.gateway = gateway
        self.hostname = hostname
        self.network = network
        self.address = address
        self.name = name
        self.id = id
    }
}

// MARK: - Registry Search Models

public struct RegistrySearchResult: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public let name: String
    public let description: String?
    public let isOfficial: Bool
    public let starCount: Int?

    public var displayName: String {
        // Remove docker.io/library/ prefix for cleaner display
        if name.hasPrefix("docker.io/library/") {
            return String(name.dropFirst("docker.io/library/".count))
        } else if name.hasPrefix("docker.io/") {
            return String(name.dropFirst("docker.io/".count))
        }
        return name
    }

    public init(
        name: String,
        description: String? = nil,
        isOfficial: Bool,
        starCount: Int? = nil
    ) {
        self.name = name
        self.description = description
        self.isOfficial = isOfficial
        self.starCount = starCount
    }
}

// MARK: - System Property Models

public struct SystemProperty: Identifiable, Equatable, Sendable {
    public let id: String
    public let type: PropertyType
    public let value: String
    public let description: String

    public enum PropertyType: String, CaseIterable, Sendable {
        case bool = "Bool"
        case string = "String"

        public var displayName: String {
            return rawValue
        }
    }

    public var displayValue: String {
        if type == .bool {
            return value == "true" ? "✓ Enabled" : "✗ Disabled"
        } else if value == "*undefined*" {
            return "Not set"
        }
        return value
    }

    public var isUndefined: Bool {
        return value == "*undefined*"
    }

    public init(
        id: String,
        type: PropertyType,
        value: String,
        description: String
    ) {
        self.id = id
        self.type = type
        self.value = value
        self.description = description
    }
}

// MARK: - Container Network Models

public struct ContainerNetwork: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let state: String
    public let config: NetworkConfig
    public let status: NetworkStatus
    /// True for a host-only (`--internal`) network: reachable from the host but with no
    /// internet egress. This is the sandbox-network property the model bridge relies on -
    /// a container on it can reach a host model server yet cannot phone home. Derived at
    /// mapping time; excluded from `CodingKeys` so synthesised `Decodable` never requires it
    /// (it would otherwise throw `keyNotFound` on payloads/fixtures that omit it) and it
    /// simply defaults to false.
    public var isHostOnly: Bool = false

    enum CodingKeys: String, CodingKey {
        case id
        case state
        case config
        case status
    }

    public init(
        id: String,
        state: String,
        config: NetworkConfig,
        status: NetworkStatus,
        isHostOnly: Bool = false
    ) {
        self.id = id
        self.state = state
        self.config = config
        self.status = status
        self.isHostOnly = isHostOnly
    }
}

public struct NetworkConfig: Codable, Equatable, Sendable {
    public let labels: [String: String]
    public let id: String

    enum CodingKeys: String, CodingKey {
        case labels
        case id
    }

    public init(
        labels: [String: String],
        id: String
    ) {
        self.labels = labels
        self.id = id
    }
}

public struct NetworkStatus: Codable, Equatable, Sendable {
    public let gateway: String?
    public let address: String?

    enum CodingKeys: String, CodingKey {
        case gateway
        case address
    }

    public init(
        gateway: String? = nil,
        address: String? = nil
    ) {
        self.gateway = gateway
        self.address = address
    }
}

// MARK: - Container Run Configuration Models

public struct ContainerRunConfig: Equatable, Sendable {
    public var name: String
    public var image: String
    public var detached: Bool = true
    public var removeAfterStop: Bool = false
    public var environmentVariables: [EnvironmentVariable] = []
    public var portMappings: [PortMapping] = []
    public var volumeMappings: [VolumeMapping] = []
    public var workingDirectory: String = ""
    public var commandOverride: String = ""
    public var dnsDomain: String = ""
    public var network: String = ""
    /// Labels to stamp on the container at creation (e.g. the sandbox marker).
    public var labels: [String: String] = [:]
    /// Label rows edited in the config form; see `effectiveLabels`.
    public var labelPairs: [LabelPair] = []
    /// Resource allocation applied at create time. Defaults match the runtime's own
    /// (4 CPUs, 1 GB) so an untouched form behaves exactly as before. Memory is carried
    /// in bytes so a value that isn't a whole number of GB (e.g. a CLI-created 1.5 GB
    /// container) survives edit and recovery untouched; the form edits it in whole GB.
    public var cpus: Int = ContainerRunConfig.defaultCPUs
    public var memoryBytes: UInt64 = ContainerRunConfig.defaultMemoryBytes

    public static let bytesPerGiB: UInt64 = 1_073_741_824
    /// What a container gets when nothing asks for anything: the runtime's own defaults.
    /// Named so that the Run form and a compose file with no `deploy.resources` agree without
    /// either of them repeating the number.
    public static let defaultCPUs: Int = 4
    public static let defaultMemoryBytes: UInt64 = ContainerRunConfig.bytesPerGiB

    /// Whole-GB view of `memoryBytes` for the form's stepper: reads rounded to the
    /// nearest GB (never below 1), writes exact whole GB. Only a user edit goes through
    /// the setter, so an untouched non-integral value keeps its exact byte count.
    public var memoryGiB: Int {
        get { max(1, Int(clamping: (memoryBytes + Self.bytesPerGiB / 2) / Self.bytesPerGiB)) }
        set { memoryBytes = UInt64(max(1, newValue)) * Self.bytesPerGiB }
    }

    public struct EnvironmentVariable: Identifiable, Equatable, Sendable {
        public let id = UUID()
        public var key: String
        public var value: String

        public init(
            key: String,
            value: String
        ) {
            self.key = key
            self.value = value
        }
    }

    /// Label namespaces owned by the runtime or Orchard itself; hidden from
    /// the form's label rows and carried through edits untouched.
    public static let internalLabelPrefixes = ["com.apple.container.", "com.orchard."]

    /// A user-edited label row in the config form. Kept separate from `labels`
    /// (programmatic, e.g. the sandbox marker) and merged over it at create
    /// time via `effectiveLabels`.
    public struct LabelPair: Identifiable, Equatable, Sendable {
        public let id = UUID()
        public var key: String
        public var value: String

        public init(
            key: String,
            value: String
        ) {
            self.key = key
            self.value = value
        }
    }

    /// Programmatic labels plus the form's rows (trimmed; empty keys dropped;
    /// on a key collision the form row wins).
    public var effectiveLabels: [String: String] {
        var merged = labels
        for pair in labelPairs {
            let key = pair.key.trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            merged[key] = pair.value.trimmingCharacters(in: .whitespaces)
        }
        return merged
    }

    public struct PortMapping: Identifiable, Equatable, Sendable {
        public let id = UUID()
        public var hostPort: String
        public var containerPort: String
        public var transportProtocol: String = "tcp"

        public init(
            hostPort: String,
            containerPort: String,
            transportProtocol: String = "tcp"
        ) {
            self.hostPort = hostPort
            self.containerPort = containerPort
            self.transportProtocol = transportProtocol
        }
    }

    public struct VolumeMapping: Identifiable, Equatable, Sendable {
        public let id = UUID()
        public var hostPath: String
        public var containerPath: String
        public var readonly: Bool = false

        public init(
            hostPath: String,
            containerPath: String,
            readonly: Bool = false
        ) {
            self.hostPath = hostPath
            self.containerPath = containerPath
            self.readonly = readonly
        }
    }

    public init(
        name: String,
        image: String,
        detached: Bool = true,
        removeAfterStop: Bool = false,
        environmentVariables: [EnvironmentVariable] = [],
        portMappings: [PortMapping] = [],
        volumeMappings: [VolumeMapping] = [],
        workingDirectory: String = "",
        commandOverride: String = "",
        dnsDomain: String = "",
        network: String = "",
        labels: [String: String] = [:],
        labelPairs: [LabelPair] = [],
        cpus: Int = ContainerRunConfig.defaultCPUs,
        memoryBytes: UInt64 = ContainerRunConfig.defaultMemoryBytes
    ) {
        self.name = name
        self.image = image
        self.detached = detached
        self.removeAfterStop = removeAfterStop
        self.environmentVariables = environmentVariables
        self.portMappings = portMappings
        self.volumeMappings = volumeMappings
        self.workingDirectory = workingDirectory
        self.commandOverride = commandOverride
        self.dnsDomain = dnsDomain
        self.network = network
        self.labels = labels
        self.labelPairs = labelPairs
        self.cpus = cpus
        self.memoryBytes = memoryBytes
    }
}

// MARK: - Container Stats Models

public struct ContainerStats: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let cpuUsageUsec: Int
    public let memoryUsageBytes: Int
    public let memoryLimitBytes: Int
    public let blockReadBytes: Int
    public let blockWriteBytes: Int
    public let networkRxBytes: Int
    public let networkTxBytes: Int
    public let numProcesses: Int

    // Computed properties for display
    public var memoryUsagePercent: Double {
        guard memoryLimitBytes > 0 else { return 0.0 }
        return Double(memoryUsageBytes) / Double(memoryLimitBytes) * 100.0
    }

    public var formattedMemoryUsage: String {
        ByteCountFormatter.string(fromByteCount: Int64(memoryUsageBytes), countStyle: .memory)
    }

    public var formattedMemoryLimit: String {
        ByteCountFormatter.string(fromByteCount: Int64(memoryLimitBytes), countStyle: .memory)
    }

    public var formattedNetworkRx: String {
        ByteCountFormatter.string(fromByteCount: Int64(networkRxBytes), countStyle: .binary)
    }

    public var formattedNetworkTx: String {
        ByteCountFormatter.string(fromByteCount: Int64(networkTxBytes), countStyle: .binary)
    }

    public var formattedBlockRead: String {
        ByteCountFormatter.string(fromByteCount: Int64(blockReadBytes), countStyle: .binary)
    }

    public var formattedBlockWrite: String {
        ByteCountFormatter.string(fromByteCount: Int64(blockWriteBytes), countStyle: .binary)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case cpuUsageUsec
        case memoryUsageBytes
        case memoryLimitBytes
        case blockReadBytes
        case blockWriteBytes
        case networkRxBytes
        case networkTxBytes
        case numProcesses
    }

    /// A copy with a different id. Used to re-key a machine's backing-container stats onto the
    /// stable machine id, so history survives the backing container id changing across reboots.
    public func with(id newId: String) -> ContainerStats {
        ContainerStats(
            id: newId,
            cpuUsageUsec: cpuUsageUsec,
            memoryUsageBytes: memoryUsageBytes,
            memoryLimitBytes: memoryLimitBytes,
            blockReadBytes: blockReadBytes,
            blockWriteBytes: blockWriteBytes,
            networkRxBytes: networkRxBytes,
            networkTxBytes: networkTxBytes,
            numProcesses: numProcesses
        )
    }

    public init(
        id: String,
        cpuUsageUsec: Int,
        memoryUsageBytes: Int,
        memoryLimitBytes: Int,
        blockReadBytes: Int,
        blockWriteBytes: Int,
        networkRxBytes: Int,
        networkTxBytes: Int,
        numProcesses: Int
    ) {
        self.id = id
        self.cpuUsageUsec = cpuUsageUsec
        self.memoryUsageBytes = memoryUsageBytes
        self.memoryLimitBytes = memoryLimitBytes
        self.blockReadBytes = blockReadBytes
        self.blockWriteBytes = blockWriteBytes
        self.networkRxBytes = networkRxBytes
        self.networkTxBytes = networkTxBytes
        self.numProcesses = numProcesses
    }
}

// MARK: - System Disk Usage Models

public struct SystemDiskUsage: Codable, Equatable, Sendable {
    public let containers: DiskUsageSection
    public let images: DiskUsageSection
    public let volumes: DiskUsageSection

    public var totalSize: Int64 {
        containers.sizeInBytes + images.sizeInBytes + volumes.sizeInBytes
    }

    public var totalReclaimable: Int64 {
        containers.reclaimable + images.reclaimable + volumes.reclaimable
    }

    public var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .binary)
    }

    public var formattedTotalReclaimable: String {
        ByteCountFormatter.string(fromByteCount: totalReclaimable, countStyle: .binary)
    }

    public init(
        containers: DiskUsageSection,
        images: DiskUsageSection,
        volumes: DiskUsageSection
    ) {
        self.containers = containers
        self.images = images
        self.volumes = volumes
    }
}

public struct DiskUsageSection: Codable, Equatable, Sendable {
    public let active: Int
    public let reclaimable: Int64
    public let sizeInBytes: Int64
    public let total: Int

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeInBytes, countStyle: .binary)
    }

    public var formattedReclaimable: String {
        ByteCountFormatter.string(fromByteCount: reclaimable, countStyle: .binary)
    }

    public var reclaimablePercent: Double {
        guard sizeInBytes > 0 else { return 0.0 }
        return Double(reclaimable) / Double(sizeInBytes) * 100.0
    }

    public init(
        active: Int,
        reclaimable: Int64,
        sizeInBytes: Int64,
        total: Int
    ) {
        self.active = active
        self.reclaimable = reclaimable
        self.sizeInBytes = sizeInBytes
        self.total = total
    }
}

extension String {
    /// A network address with any CIDR suffix removed, e.g. "10.0.0.2/24" → "10.0.0.2".
    /// Generic over the prefix length - the previous hard-coded "/24" strip left "/16", "/8",
    /// etc. attached to copied addresses.
    public var strippingCIDRSuffix: String {
        guard let slash = firstIndex(of: "/") else { return self }
        return String(self[..<slash])
    }
}
