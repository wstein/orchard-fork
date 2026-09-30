import Foundation
import OrchardApplication
import OrchardDomain
import Testing

@Test("Shared start retries transition errors and returns a structured terminal failure")
func startRetryPolicy() async throws {
    let backend = TestBackend()
    await backend.setErrors([.generic("invalidState"), .generic("shuttingDown")])
    let operations = ContainerOperations(backend: backend)
    try await operations.start("api", maxRetries: 3, retryDelay: 0)
    #expect(await backend.attempts == 3)

    await backend.setErrors([.generic("disk is on fire")])
    await #expect(throws: OrchardError.generic("disk is on fire")) {
        try await operations.start("api", maxRetries: 3, retryDelay: 0)
    }
    #expect(await backend.attempts == 4)
}

@Test("Shared recovery preserves exact resources, labels, environment, and narrow port binding")
func recoveryPreservesConfiguration() async throws {
    let backend = TestBackend()
    await backend.setContainers([fixtureContainer()])
    let operations = ContainerOperations(backend: backend)
    _ = try await operations.list()
    await backend.setErrors([.generic("container not found")])
    try await operations.start("api", retryDelay: 0)
    let specs = await backend.created
    let spec = try #require(specs.first)
    #expect(await backend.attempts == 1)
    #expect(spec.memoryBytes == 1_610_612_736)
    #expect(spec.cpus == 3)
    #expect(spec.labels == ["com.orchard.sandbox": "true"])
    #expect(spec.environment == ["TOKEN=secret", "EMPTY="])
    #expect(spec.publishedPorts.first?.hostAddress == "127.0.0.1")
    #expect(spec.volumes.first?.readonly == true)
    #expect(spec.networkName == "private")
    #expect(spec.commandOverride.isEmpty) // Do not apply the image entrypoint twice.
}

@Test("Missing recovery snapshots produce a structured failure")
func missingRecoverySnapshot() async {
    let backend = TestBackend()
    await backend.setErrors([.generic("not found")])
    let operations = ContainerOperations(backend: backend)
    await #expect(throws: OrchardError.recoveryFailed(id: "api")) {
        try await operations.start("api", retryDelay: 0)
    }
}

@Test("Shared create uses quote-aware arguments, exact memory, and merged labels")
func sharedCreateSpec() async throws {
    let backend = TestBackend()
    let operations = ContainerOperations(backend: backend)
    var config = ContainerRunConfig(name: "api", image: "alpine", memoryBytes: 1_610_612_736)
    config.commandOverride = "sh -c \"echo hi\""
    config.labelPairs = [.init(key: "team", value: "infra")]
    let id = try await operations.create(config)
    #expect(id == "api")
    let specs = await backend.created
    let spec = try #require(specs.first)
    #expect(spec.commandOverride == ["sh", "-c", "echo hi"])
    #expect(spec.memoryBytes == 1_610_612_736)
    #expect(spec.labels == ["team": "infra"])
}

@Test("Concurrent lifecycle calls cannot mutate the same container")
func conflictingOperations() async throws {
    let backend = TestBackend()
    let gate = TestGate()
    await backend.setGate(gate)
    let operations = ContainerOperations(backend: backend)
    let first = Task { try await operations.start("api", retryDelay: 0) }
    await gate.waitUntilEntered()
    await #expect(throws: OrchardError.containerInTransition(id: "api")) {
        try await operations.stop("api")
    }
    await gate.open()
    try await first.value
    try await operations.stop("api")
    #expect(await backend.stopped == ["api"])
}

actor TestGate {
    private var entered = false
    private var released = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var enteredWaiters: [CheckedContinuation<Void, Never>] = []
    func wait() async {
        entered = true
        enteredWaiters.forEach { $0.resume() }
        enteredWaiters = []
        if !released { await withCheckedContinuation { waiters.append($0) } }
    }
    func waitUntilEntered() async {
        if !entered { await withCheckedContinuation { enteredWaiters.append($0) } }
    }
    func open() {
        released = true
        waiters.forEach { $0.resume() }
        waiters = []
    }
}

actor TestBackend: ContainerBackend {
    var attempts = 0
    var created: [ContainerCreateSpec] = []
    var stopped: [String] = []
    private var errors: [OrchardError] = []
    private var containers: [Container] = []
    private var gate: TestGate?
    func setErrors(_ errors: [OrchardError]) { self.errors = errors }
    func setContainers(_ containers: [Container]) { self.containers = containers }
    func setGate(_ gate: TestGate) { self.gate = gate }
    func listContainers() async throws -> [Container] { containers }
    func bootstrapAndStart(id: String) async throws {
        attempts += 1
        if let gate { await gate.wait() }
        if !errors.isEmpty { throw errors.removeFirst() }
    }
    func createContainer(_ spec: ContainerCreateSpec) async throws { created.append(spec) }
    func stopContainer(id: String) async throws { stopped.append(id) }
    func killContainer(id: String, signal: Int32) async throws {}
    func deleteContainer(id: String, force: Bool) async throws {}
    func containerLogs(id: String) async throws -> [FileHandle] { [] }
    func exportContainer(id: String, to destination: URL) async throws {}
    func cleanContainer(id: String) async throws {}
    func stats(id: String) async throws -> ContainerStats { throw OrchardError.generic("unsupported") }
    func listImages() async throws -> [ContainerImage] { [] }
    func pullImage(reference: String, onProgress: (@Sendable (ImagePullMetrics) -> Void)?) async throws {}
    func deleteImage(reference: String) async throws {}
    func inspectImage(reference: String) async throws -> ImageInspection { throw OrchardError.generic("unsupported") }
    func listNetworks() async throws -> [ContainerNetwork] { [] }
    func createNetwork(name: String, subnet: String?, labels: [String: String]) async throws {}
    func deleteNetwork(id: String) async throws {}
    func ping() async throws -> SystemHealthInfo { .init(apiServerVersion: "1.4.1") }
    func diskUsage() async throws -> SystemDiskUsage { throw OrchardError.generic("unsupported") }
}

func fixtureContainer() -> Container {
    Container(status: "stopped", configuration: .init(
        id: "api", networkName: "private", runtimeHandler: "vz",
        initProcess: .init(terminal: false, environment: ["TOKEN=secret", "EMPTY="],
                           workingDirectory: "/work", arguments: ["-c", "echo hi"], executable: "sh",
                           user: .init(id: .init(gid: 0, uid: 0)), rlimits: [], supplementalGroups: []),
        mounts: [.init(type: .init(virtiofs: .init()), source: "/tmp", options: ["ro"], destination: "/data")],
        platform: .init(os: "linux", architecture: "arm64"),
        image: .init(descriptor: .init(mediaType: "test", digest: "sha256:test", size: 0), reference: "alpine"),
        rosetta: false, dns: .init(nameservers: [], searchDomains: [], options: [], domain: "test"),
        resources: .init(cpus: 3, memoryInBytes: 1_610_612_736), labels: ["com.orchard.sandbox": "true"],
        publishedPorts: [.init(hostPort: 8080, containerPort: 80, transportProtocol: "tcp", hostAddress: "127.0.0.1")],
        sysctls: [:]
    ), networks: [])
}
