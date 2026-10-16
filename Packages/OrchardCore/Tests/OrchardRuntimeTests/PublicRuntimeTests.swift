import OrchardDomain
import OrchardRuntime
import Testing

@Test("Independent consumers can construct all live runtime adapters")
func publicRuntimeAdapters() {
    let _: any ContainerBackend = LiveContainerBackend()
    let _: any MachineBackend = LiveMachineBackend()
    let _: any ModelBackend = LiveModelBackend()
    let _: any CommandRunner = SystemCommandRunner()
    let _: any SecretsStore = KeychainSecretsStore()
}

@Test("Runtime commands preserve literal arguments without a shell")
func runtimeLiteralArguments() async throws {
    let value = "$(echo unexpected); quoted 'value'"
    let result = try await SystemCommandRunner().run(program: "/usr/bin/printf", arguments: ["%s", value])
    #expect(result.exitCode == 0)
    #expect(result.stdout == value)
}
