import Foundation
import AppKit
import OrchardDomain

// MARK: - Sort Options

enum ContainerSortOption: String, CaseIterable {
    case name = "name"
    case status = "status"
    case image = "image"

    var label: String {
        switch self {
        case .name: return "Name"
        case .status: return "Status"
        case .image: return "Image"
        }
    }
}

enum ImageSortOption: String, CaseIterable {
    case name = "name"
    case tag = "tag"
    case size = "size"

    var label: String {
        switch self {
        case .name: return "Name"
        case .tag: return "Tag"
        case .size: return "Size"
        }
    }
}

// MARK: - Image Size Status

enum ImageSizeStatus: Equatable {
    case loading
    case known(Int64)
    case failed
}

// MARK: - Image Pull Models

struct ImagePullProgress: Identifiable, Equatable {
    let id = UUID()
    let imageName: String
    var status: PullStatus
    var progress: Double
    var message: String
    /// Byte/item counts folded from the pull's progress events; nil until the
    /// first event arrives (and always nil for a backend without progress).
    var metrics: ImagePullMetrics?

    enum PullStatus: Equatable {
        case pulling
        case completed
        case failed(String)
    }

    /// 0…1 when the total download size is known, else nil (indeterminate).
    var fraction: Double? {
        guard let metrics, metrics.totalBytes > 0 else { return nil }
        return min(1.0, Double(metrics.bytesDownloaded) / Double(metrics.totalBytes))
    }

    /// e.g. "245 MB / 512 MB · 3/8 blobs"
    var detailText: String? {
        guard let metrics, metrics.totalBytes > 0 else { return nil }
        var parts = ["\(ByteFormat.string(metrics.bytesDownloaded)) / \(ByteFormat.string(metrics.totalBytes))"]
        if metrics.totalItems > 0 {
            parts.append("\(metrics.itemsCompleted)/\(metrics.totalItems) \(metrics.itemsName)")
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Terminal App Models

enum TerminalApp: String, CaseIterable {
    case terminal = "com.apple.Terminal"
    case iterm2 = "com.googlecode.iterm2"
    case ghostty = "com.mitchellh.ghostty"

    var displayName: String {
        switch self {
        case .terminal:
            return "Terminal"
        case .iterm2:
            return "iTerm2"
        case .ghostty:
            return "Ghostty"
        }
    }

    var bundleIdentifier: String {
        return rawValue
    }

    var isInstalled: Bool {
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
    }

    static var installedTerminals: [TerminalApp] {
        return allCases.filter { $0.isInstalled }
    }
}
