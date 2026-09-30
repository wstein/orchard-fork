import OrchardApplication
import OrchardDomain
import Foundation
import SwiftUI

/// Owns the container list and lifecycle: load, start (with retry/recovery), stop, kill,
/// remove, run, recreate, logs, and the mounts derived from the list.
@MainActor
final class ContainerListService: ObservableObject {
    @Published var containers: [Container] = [] {
        didSet { allMounts = Self.computeMounts(containers) }
    }
    /// Unique mounts across the current containers. Recomputed only when `containers`
    /// changes, not on every read - several views read it on each objectWillChange tick.
    @Published private(set) var allMounts: [ContainerMount] = []
    @Published var loadingContainers: Set<String> = []
    @Published var isLoading: Bool = false
    /// Containers whose automatic recovery failed - drives the persistent "Recreate"
    /// affordance, which must outlive the transient alert. Cleared on a successful start.
    @Published var recoveryFailedContainerIDs: Set<String> = []
    /// Containers with a filesystem export in flight - drives the per-container
    /// "Exporting…" affordance.
    @Published private(set) var exportingContainers: Set<String> = []
    /// Containers with a disk-space reclaim in flight - drives the per-container
    /// "Reclaiming…" affordance.
    @Published private(set) var cleaningContainers: Set<String> = []

    private let backend: ContainerBackend
    private let operations: ContainerOperations
    private let alertCenter: AlertCenter

    /// Refresh builder state after a lifecycle change. Set by the owner.
    var reloadBuilders: () async -> Void = {}
    /// Refresh the system disk usage a reclaim has just changed. Set by the owner.
    var reloadDiskUsage: () async -> Void = {}

    /// Delay between polls in the `refreshUntilContainer…` loops. Injected; production uses
    /// the 0.5s default, tests pass 0 to drive the loops without real sleeps.
    private let pollInterval: TimeInterval
    /// Number of polls before a refresh loop gives up and clears the loading state.
    let maxRefreshAttempts = 10

    // Prevent multiple simultaneous operations on the same container.
    private var containerOperationLocks: Set<String> = []
    private let lockQueue = DispatchQueue(label: "containerOperationLocks", attributes: .concurrent)

    init(backend: ContainerBackend, alertCenter: AlertCenter, pollInterval: TimeInterval = 0.5) {
        self.backend = backend
        self.operations = ContainerOperations(backend: backend)
        self.alertCenter = alertCenter
        self.pollInterval = pollInterval
    }

    private static func computeMounts(_ containers: [Container]) -> [ContainerMount] {
        var mountDict: [String: ContainerMount] = [:]
        for container in containers {
            for mount in container.configuration.mounts {
                let mountId = "\(mount.source)->\(mount.destination)"
                if let existingMount = mountDict[mountId] {
                    var updatedContainerIds = existingMount.containerIds
                    if !updatedContainerIds.contains(container.configuration.id) {
                        updatedContainerIds.append(container.configuration.id)
                    }
                    mountDict[mountId] = ContainerMount(mount: mount, containerIds: updatedContainerIds)
                } else {
                    mountDict[mountId] = ContainerMount(mount: mount, containerIds: [container.configuration.id])
                }
            }
        }
        return Array(mountDict.values).sorted { $0.mount.source < $1.mount.source }
    }

    private func areContainersEqual(_ old: [Container], _ new: [Container]) -> Bool {
        old == new
    }

    func loadContainers(showLoading: Bool = false) async {
        if showLoading {
            isLoading = true
            self.alertCenter.dismiss()
        }

        do {
            let newContainers = try await operations.list()

            if !areContainersEqual(self.containers, newContainers) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.containers = newContainers
                }
            }
            self.isLoading = false
            for container in newContainers {
                Log.containers.debug("Container: \(container.configuration.id), Status: \(container.status)")
            }
        } catch {
            // Background refreshes stay silent; only a user-initiated load alerts.
            self.alertCenter.error(error.localizedDescription, source: showLoading ? .user : .background)
            self.isLoading = false
            Log.containers.error("\(error.localizedDescription)")
        }
    }

    func forceStopContainer(_ id: String) async {
        loadingContainers.insert(id)
        self.alertCenter.dismiss()

        do {
            try await operations.forceStop(id)
            Log.containers.debug("Container \(id) force stop (SIGKILL) sent")
            Task { await self.reloadBuilders() }
            Task { await self.refreshUntilContainerStopped(id) }
        } catch {
            loadingContainers.remove(id)
            self.alertCenter.error("Failed to force stop container: \(error.localizedDescription)")
            Log.containers.error("Error force stopping container: \(error.localizedDescription)")
        }
    }

    func stopContainer(_ id: String) async {
        loadingContainers.insert(id)
        self.alertCenter.dismiss()

        do {
            try await operations.stop(id)
            Log.containers.debug("Container \(id) stop command sent successfully")
            Task { await self.reloadBuilders() }
            Task { await self.refreshUntilContainerStopped(id) }
        } catch {
            loadingContainers.remove(id)
            self.alertCenter.error("Failed to stop container: \(error.localizedDescription)")
            Log.containers.error("Error stopping container: \(error.localizedDescription)")
        }
    }

    func startContainer(_ id: String, maxRetries: Int = 3, retryDelay: TimeInterval = 1.0) async {
        let shouldProceed = lockQueue.sync(flags: .barrier) {
            if containerOperationLocks.contains(id) { return false }
            containerOperationLocks.insert(id)
            return true
        }

        defer {
            if shouldProceed {
                _ = lockQueue.sync(flags: .barrier) { containerOperationLocks.remove(id) }
            }
        }

        guard shouldProceed else {
            Log.containers.debug("DEBUG: Container \(id) operation already in progress, ignoring duplicate call")
            return
        }

        await startContainerWithRetry(id, maxRetries: maxRetries, retryDelay: retryDelay)
    }

    private func startContainerWithRetry(_ id: String, maxRetries: Int, retryDelay: TimeInterval) async {
        loadingContainers.insert(id)
        alertCenter.dismiss()
        do {
            try await operations.start(id, maxRetries: maxRetries, retryDelay: retryDelay)
            recoveryFailedContainerIDs.remove(id)
            Task { await self.reloadBuilders() }
            Task { await self.refreshUntilContainerStarted(id) }
        } catch {
            if let failure = error as? OrchardError, failure == .recoveryFailed(id: id) {
                recoveryFailedContainerIDs.insert(id)
            }
            if let failure = error as? OrchardError, failure == .containerInTransition(id: id) {
                alertCenter.error("Container failed to start after \(maxRetries) attempts. The container may be corrupted.")
            } else {
                alertCenter.error("Failed to start container: \(error.localizedDescription)")
            }
            loadingContainers.remove(id)
            Log.containers.error("Error starting container: \(error.localizedDescription)")
            Task { await self.loadContainers() }
        }
    }

    private func refreshUntilContainerStopped(_ id: String) async {
        var attempts = 0

        while attempts < maxRefreshAttempts {
            await loadContainers()

            let shouldStop: Bool
            if let container = containers.first(where: { $0.configuration.id == id }) {
                Log.containers.debug("Checking stop status for \(id): \(container.status)")
                shouldStop = container.status.lowercased() != "running"
            } else {
                Log.containers.debug("Container \(id) not found, assuming stopped")
                shouldStop = true
            }

            if shouldStop {
                Log.containers.debug("Container \(id) has stopped, removing loading state")
                loadingContainers.remove(id)
                return
            }

            attempts += 1
            Log.containers.debug("Container \(id) still running, attempt \(attempts)/\(self.maxRefreshAttempts)")
            try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }

        Log.containers.debug("Timeout reached for container \(id), removing loading state")
        loadingContainers.remove(id)
    }

    private func refreshUntilContainerStarted(_ id: String) async {
        var attempts = 0

        while attempts < maxRefreshAttempts {
            await loadContainers()

            let isRunning: Bool
            if let container = containers.first(where: { $0.configuration.id == id }) {
                Log.containers.debug("Checking start status for \(id): \(container.status)")
                isRunning = container.status.lowercased() == "running"
            } else {
                isRunning = false
            }

            if isRunning {
                Log.containers.debug("Container \(id) has started, removing loading state")
                loadingContainers.remove(id)
                return
            }

            attempts += 1
            Log.containers.debug("Container \(id) not running yet, attempt \(attempts)/\(self.maxRefreshAttempts)")
            try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }

        Log.containers.debug("Timeout reached for container \(id), removing loading state")
        loadingContainers.remove(id)
    }

    func removeContainer(_ id: String) async {
        loadingContainers.insert(id)
        self.alertCenter.dismiss()

        do {
            try await operations.remove(id)
            Log.containers.debug("Container \(id) remove command sent successfully")
            Task { await self.reloadBuilders() }
            self.containers.removeAll { $0.configuration.id == id }
            loadingContainers.remove(id)
        } catch {
            loadingContainers.remove(id)
            self.alertCenter.error("Failed to remove container: \(error.localizedDescription)")
            Log.containers.error("Error removing container: \(error.localizedDescription)")
        }
    }

    func removeContainers(_ ids: [String]) async {
        for id in ids {
            await removeContainer(id)
        }
    }

    /// Export a container's filesystem to a tar archive. Returns true on
    /// success so callers can reveal the file; failures alert and log.
    @discardableResult
    func exportContainer(_ id: String, to destination: URL) async -> Bool {
        exportingContainers.insert(id)
        defer { exportingContainers.remove(id) }

        do {
            try await backend.exportContainer(id: id, to: destination)
            Log.containers.debug("Container \(id) exported to \(destination.path)")
            return true
        } catch {
            self.alertCenter.error("Failed to export container: \(error.localizedDescription)")
            Log.containers.error("Error exporting container: \(error.localizedDescription)")
            return false
        }
    }

    /// Trim the free blocks in a running container's root filesystem and volumes.
    /// Deleting files inside a container doesn't shrink its host-side disk images on
    /// its own; this hands those blocks back, so the system disk usage is refreshed
    /// once the daemon reports the trim done. Returns true on success.
    @discardableResult
    func cleanContainer(_ id: String) async -> Bool {
        // One trim per container at a time. `cleanContainers` suspends between ids, so the
        // detail header can start its own reclaim of an id the batch hasn't reached yet;
        // without this guard both run, and whichever finishes first clears the in-flight
        // flag while the other is still going. The check and the insert share a MainActor
        // turn, so nothing interleaves between them.
        guard !cleaningContainers.contains(id) else { return false }
        cleaningContainers.insert(id)
        defer { cleaningContainers.remove(id) }

        do {
            try await backend.cleanContainer(id: id)
            Log.containers.debug("Container \(id) reclaimed disk space")
            await reloadDiskUsage()
            return true
        } catch {
            // The daemon's nested "failed to clean container / clean mounts / trim failed"
            // chain is unreadable in an alert; log it whole and show the classified form.
            self.alertCenter.error(OrchardError.classifyCleanError(error, id: id))
            Log.containers.error("Error reclaiming disk space: \(error.localizedDescription)")
            return false
        }
    }

    func cleanContainers(_ ids: [String]) async {
        for id in ids {
            await cleanContainer(id)
        }
    }

    func fetchContainerLogs(containerId: String, tailLines: Int = 5000) async throws -> [String] {
        let fileHandles = try await backend.containerLogs(id: containerId)

        // The API returns [containerLog, bootlog] - only read the first (container log).
        guard let containerLog = fileHandles.first else {
            return []
        }

        return try await Task.detached {
            let data = containerLog.readDataToEndOfFile()
            guard let fullText = String(data: data, encoding: .utf8) else {
                return [String]()
            }
            let lines = fullText.components(separatedBy: "\n")
            if lines.count > tailLines {
                return Array(lines.suffix(tailLines))
            }
            return lines
        }.value
    }

    func recreateContainer(oldContainerId: String, newConfig: ContainerRunConfig) async {
        do {
            try await backend.deleteContainer(id: oldContainerId, force: true)
            await runContainer(config: newConfig)
        } catch {
            self.alertCenter.error("Failed to recreate container: \(error.localizedDescription)")
        }
    }

    @discardableResult
    func runContainer(config: ContainerRunConfig) async -> Bool {
        do {
            let id = try await operations.create(config)
            recoveryFailedContainerIDs.remove(id)
            Task { await self.loadContainers() }
            return true
        } catch {
            alertCenter.error("Failed to run container: \(error.localizedDescription)")
            return false
        }
    }

    func deleteMounts(_ mounts: [ContainerMount]) async {
        var deletedCount = 0
        var failedCount = 0
        
        var mountsToRemoveByContainer: [String: Set<String>] = [:]
        for mount in mounts {
            for containerId in mount.containerIds {
                let key = "\(mount.mount.source)|\(mount.mount.destination)"
                mountsToRemoveByContainer[containerId, default: []].insert(key)
            }
        }
        
        for (containerId, keysToRemove) in mountsToRemoveByContainer {
            let shouldProceed = lockQueue.sync(flags: .barrier) {
                if containerOperationLocks.contains(containerId) { return false }
                containerOperationLocks.insert(containerId)
                return true
            }
            
            defer {
                if shouldProceed {
                    _ = lockQueue.sync(flags: .barrier) { containerOperationLocks.remove(containerId) }
                }
            }
            
            guard shouldProceed else {
                failedCount += 1
                continue
            }
            
            guard let container = containers.first(where: { $0.configuration.id == containerId }) else {
                failedCount += 1
                continue
            }
            
            let oldConfig = container.configuration
            let updatedMounts = oldConfig.mounts.filter { m in
                let key = "\(m.source)|\(m.destination)"
                return !keysToRemove.contains(key)
            }
            
            var envVars: [ContainerRunConfig.EnvironmentVariable] = []
            for env in oldConfig.initProcess.environment {
                let parts = env.split(separator: "=", maxSplits: 1)
                if parts.count == 2 {
                    envVars.append(.init(key: String(parts[0]), value: String(parts[1])))
                }
            }
            
            var portMappings: [ContainerRunConfig.PortMapping] = []
            for port in oldConfig.publishedPorts {
                portMappings.append(.init(
                    hostPort: "\(port.hostPort)",
                    containerPort: "\(port.containerPort)",
                    transportProtocol: port.transportProtocol
                ))
            }
            
            var volumeMappings: [ContainerRunConfig.VolumeMapping] = []
            for m in updatedMounts {
                let isReadonly = m.options.contains("ro")
                volumeMappings.append(.init(
                    hostPath: m.source,
                    containerPath: m.destination,
                    readonly: isReadonly
                ))
            }
            
            let runConfig = ContainerRunConfig(
                name: oldConfig.id,
                image: oldConfig.image.reference,
                detached: true,
                removeAfterStop: false,
                environmentVariables: envVars,
                portMappings: portMappings,
                volumeMappings: volumeMappings,
                workingDirectory: oldConfig.initProcess.workingDirectory,
                commandOverride: oldConfig.initProcess.arguments.joined(separator: " "),
                dnsDomain: oldConfig.dns.domain ?? "",
                network: container.networks.first?.network ?? "",
                // The mount-removal recreate must carry labels through too.
                labels: oldConfig.labels
            )
            
            do {
                try await backend.deleteContainer(id: containerId, force: true)
                let started = await runContainer(config: runConfig)
                if started {
                    deletedCount += 1
                } else {
                    failedCount += 1
                }
            } catch {
                failedCount += 1
            }
        }
        await loadContainers(showLoading: false)
        if failedCount > 0 {
            alertCenter.error("Failed to remove mount(s) from \(failedCount) container(s)")
        }
    }

}
