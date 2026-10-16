import Foundation

/// Minimal secret storage keyed by an account string. Production uses the keychain so
/// credentials never sit in UserDefaults; tests inject the in-memory variant so they
/// never touch the real keychain.
public protocol SecretsStore: Sendable {
    func secret(for account: String) -> String?
    /// nil or empty removes the stored secret. Throws when the store refuses the write:
    /// a credential that silently failed to save looks exactly like one that saved, which
    /// is what made a rejected keychain write impossible to tell from a rejected API key
    /// (#110).
    func setSecret(_ value: String?, for account: String) throws
    func allSecrets() -> [String: String]
}

