import OrchardDomain
import Foundation

// MARK: - Supervised process

/// A long-running child process Orchard supervises. Abstracted so the service can be tested
/// without spawning real processes (`Process` waits for exit; a model server never exits on
/// its own). `terminationHandler` fires with the exit code when the process ends, on an
/// arbitrary thread - callers hop to their actor.

/// `ServerProcess` backed by a real `Process`, streaming stdout+stderr to a log file. Using
/// a file (not a `Pipe`) avoids the drain-or-deadlock dance `CommandRunner` needs - but it
/// also means we never call `waitUntilExit`, so the server runs detached until stopped.
// Process is owned by this adapter; the mutable callback is synchronized.
final class LiveServerProcess: ServerProcess, @unchecked Sendable {
    private let process: Process
    private let callbackLock = NSLock()
    private var callback: ((Int32) -> Void)?
    var terminationHandler: ((Int32) -> Void)? {
        get { callbackLock.withLock { callback } }
        set { callbackLock.withLock { callback = newValue } }
    }

    public init(process: Process) {
        self.process = process
        // `Process` fires this on an arbitrary thread; deliver on main so the service's
        // handler runs main-actor-isolated (see `ModelServerService`).
        process.terminationHandler = { [weak self] proc in
            let code = proc.terminationStatus
            DispatchQueue.main.async { self?.terminationHandler?(code) }
        }
    }

    public func terminate() {
        if process.isRunning { process.terminate() }
    }
}

// MARK: - Engine

/// Launches model-server processes. The managed-provider seam: swappable so the engine
/// (mlx_lm.server today, potentially oMLX later) doesn't leak into the service or views.

public enum ModelServerEngineError: LocalizedError {
    case binaryNotFound

    public var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "mlx_lm.server was not found. Install it with: uv tool install mlx-lm"
        }
    }
}

/// `ModelServerEngine` for Apple's `mlx_lm.server` (OpenAI-compatible, runs inference on the
/// Apple GPU). Located via the stable path `uv tool install mlx-lm` creates.
public struct MLXServerEngine: ModelServerEngine {
    public init() {}

    /// The launch argument vector - pure, so it is unit-tested directly.
    public static func launchArguments(model: String, host: String, port: UInt16) -> [String] {
        ["--model", model, "--host", host, "--port", String(port)]
    }

    public func locateBinary() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        // `uv tool install mlx-lm` symlinks the entry points into ~/.local/bin.
        let candidates = [
            home.appendingPathComponent(".local/bin/mlx_lm.server").path,
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    public func launch(model: String, host: String, port: UInt16, logURL: URL) throws -> ServerProcess {
        guard let binary = locateBinary() else { throw ModelServerEngineError.binaryNotFound }

        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: logURL)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = Self.launchArguments(model: model, host: host, port: port)
        process.standardOutput = handle
        process.standardError = handle
        try process.run()
        return LiveServerProcess(process: process)
    }
}
