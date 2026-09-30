import Foundation

/// One place for human-readable byte sizes, replacing the `ByteCountFormatter().string(...)`
/// calls scattered across the views.
public enum ByteFormat: Sendable {
    public static func string(_ bytes: Int64) -> String {
        ByteCountFormatter().string(fromByteCount: bytes)
    }

    public static func string(_ bytes: Int) -> String {
        string(Int64(bytes))
    }

    /// Binary (1024-based) sizing for RAM-style readings, so memory usage reads in MiB/GiB.
    /// Use this for every live-stats memory value — mixing it with `string`'s decimal sizing
    /// made the same container show different byte strings across the dashboard/menu-bar.
    public static func memory(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: bytes)
    }

    public static func memory(_ bytes: Int) -> String {
        memory(Int64(bytes))
    }
}
