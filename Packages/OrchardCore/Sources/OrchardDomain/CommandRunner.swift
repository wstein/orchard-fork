import Foundation

/// Result of running an external process.
public struct ProcessResult: Sendable {
    public let exitCode: Int32
    public let stdout: String?
    public let stderr: String?
    public var failed: Bool { exitCode != 0 }

    public init(
        exitCode: Int32,
        stdout: String? = nil,
        stderr: String? = nil
    ) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }
}

/// Abstraction over running external CLI commands, so callers can be driven with a
/// mock in tests. `run` is `async` and executes off the main actor.
public protocol CommandRunner: Sendable {
    func run(program: String, arguments: [String]) async throws -> ProcessResult
    func runWithSudo(program: String, arguments: [String]) async throws -> ProcessResult
    /// Like `run`, but delivers combined stdout+stderr output line by line while
    /// the process executes (image builds run for minutes and report progress as
    /// they go). Cancelling the surrounding task terminates the process.
    func runStreaming(
        program: String,
        arguments: [String],
        onLine: @escaping @Sendable (String) -> Void
    ) async throws -> ProcessResult
}

extension CommandRunner {
    /// Mocks and callers that never stream fall back to buffered execution,
    /// emitting the collected output as lines once the process exits.
    public func runStreaming(
        program: String,
        arguments: [String],
        onLine: @escaping @Sendable (String) -> Void
    ) async throws -> ProcessResult {
        let result = try await run(program: program, arguments: arguments)
        for text in [result.stdout, result.stderr] {
            guard let text, !text.isEmpty else { continue }
            for line in text.components(separatedBy: "\n") {
                onLine(line)
            }
        }
        return result
    }
}

