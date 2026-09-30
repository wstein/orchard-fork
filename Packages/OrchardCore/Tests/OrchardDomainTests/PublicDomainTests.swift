import Foundation
import OrchardDomain
import Testing

// Deliberately use a normal import: consumers must not require @testable access.
@Test("External consumers can construct and round-trip resource snapshots")
func publicSnapshotsRoundTrip() throws {
    let network = ContainerNetwork(
        id: "private", state: "running",
        config: NetworkConfig(labels: [:], id: "private"),
        status: NetworkStatus(gateway: "192.168.64.1", address: "192.168.64.0/24")
    )
    let data = try JSONEncoder().encode(network)
    #expect(try JSONDecoder().decode(ContainerNetwork.self, from: data) == network)
    #expect(network.status.address?.strippingCIDRSuffix == "192.168.64.0")
}

@Test("Shared configuration retains exact resources and merged labels")
func sharedConfiguration() {
    var config = ContainerRunConfig(name: "api", image: "alpine:latest", memoryBytes: 1_610_612_736)
    config.labels = ["com.orchard.sandbox": "true", "team": "old"]
    config.labelPairs = [.init(key: " team ", value: " new ")]
    #expect(config.memoryBytes == 1_610_612_736)
    #expect(config.effectiveLabels == ["com.orchard.sandbox": "true", "team": "new"])
    #expect(InputValidation.isValidNetworkName("private-net"))
    #expect(!InputValidation.isValidSubnet("256.1.1.1/24"))
}

@Test("Shared snapshots and specifications cross concurrency boundaries")
func sharedValuesAreSendable() async throws {
    let stats = ContainerStats(id: "api", cpuUsageUsec: 7, memoryUsageBytes: 10,
                               memoryLimitBytes: 20, blockReadBytes: 0, blockWriteBytes: 0,
                               networkRxBytes: 0, networkTxBytes: 0, numProcesses: 1)
    let copy = await Task.detached { stats.with(id: "machine") }.value
    #expect(copy.id == "machine")
    #expect(copy.memoryUsagePercent == 50)
}
