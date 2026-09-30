import Foundation

/// An engine-owned child process. Callbacks are delivered on the main queue by the live adapter.
public protocol ServerProcess: AnyObject {
    var terminationHandler: ((Int32) -> Void)? { get set }
    func terminate()
}

/// Supervised model-server process creation, independent of either GUI.
public protocol ModelServerEngine: Sendable {
    func locateBinary() -> String?
    func launch(model: String, host: String, port: UInt16, logURL: URL) throws -> any ServerProcess
}
