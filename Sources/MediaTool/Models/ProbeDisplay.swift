import Foundation

/// Cached facts about an input file, shown in the staged list.
struct ProbeDisplay {
    var width: Int?
    var height: Int?
    var codec: String?
    var duration: Double?
    var sizeBytes: Int64?

    /// A compact one-line summary, e.g. "1280×720 · h264 · 0:05 · 2.3 MB".
    var summary: String {
        var parts: [String] = []
        if let w = width, let h = height { parts.append("\(w)×\(h)") }
        if let c = codec { parts.append(c) }
        if let d = duration { parts.append(Self.formatDuration(d)) }
        if let s = sizeBytes { parts.append(Self.formatBytes(s)) }
        return parts.joined(separator: " · ")
    }

    static func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    static func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
