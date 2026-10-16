import Foundation

// MARK: - Boundary value types

/// Everything needed to create a container machine, in app-owned types so the backend
/// boundary never leaks the client's config types. `memoryGiB`/`cpus`/`homeMount` nil means
/// "use the runtime default" (memory defaults to half of host RAM).
public struct MachineCreateSpec: Sendable {
    public let name: String
    public let imageRef: String
    public let cpus: Int?
    public let memoryGiB: Int?
    /// `ro` / `rw` / `none`, or nil for the default (`rw`).
    public let homeMount: String?
    public let virtualization: Bool
    public let kernelPath: String?
    public let setDefault: Bool
    public let noBoot: Bool

    public init(
        name: String,
        imageRef: String,
        cpus: Int? = nil,
        memoryGiB: Int? = nil,
        homeMount: String? = nil,
        virtualization: Bool,
        kernelPath: String? = nil,
        setDefault: Bool,
        noBoot: Bool
    ) {
        self.name = name
        self.imageRef = imageRef
        self.cpus = cpus
        self.memoryGiB = memoryGiB
        self.homeMount = homeMount
        self.virtualization = virtualization
        self.kernelPath = kernelPath
        self.setDefault = setDefault
        self.noBoot = noBoot
    }
}

/// Editable boot-time configuration for an existing machine. Applied via `setConfig`, which
/// only takes effect on the next boot (the service can orchestrate a restart).
public struct MachineConfigSpec: Sendable {
    public let cpus: Int
    public let memoryGiB: Int
    public let homeMount: String
    public let virtualization: Bool
    public let kernelPath: String?

    public init(
        cpus: Int,
        memoryGiB: Int,
        homeMount: String,
        virtualization: Bool,
        kernelPath: String? = nil
    ) {
        self.cpus = cpus
        self.memoryGiB = memoryGiB
        self.homeMount = homeMount
        self.virtualization = virtualization
        self.kernelPath = kernelPath
    }
}

// MARK: - Backend protocol

/// The container-machine runtime surface, expressed entirely in app domain models. Mocks
/// conforming to this need no client-package imports. Mirrors `ContainerBackend`'s design
/// rule: no package types cross this boundary.
public protocol MachineBackend: Sendable {
    func listMachines() async throws -> [Machine]
    func inspectMachine(id: String) async throws -> Machine
    func createMachine(_ spec: MachineCreateSpec) async throws
    /// Update a machine's boot config. Takes effect on the next boot.
    func setMachineConfig(id: String, config: MachineConfigSpec) async throws
    func bootMachine(id: String) async throws
    func stopMachine(id: String) async throws
    /// Delete a machine. This removes its persistent storage.
    func deleteMachine(id: String) async throws
    func setDefaultMachine(id: String) async throws
    func machineLogs(id: String) async throws -> [FileHandle]
}

