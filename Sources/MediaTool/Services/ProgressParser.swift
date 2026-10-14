import Foundation

/// Parses ffmpeg's `-progress pipe:1` key=value stream into a 0…1 fraction.
///
/// ffmpeg emits blocks like:
///   out_time_us=1234567
///   out_time_ms=1234567      (note: historically microseconds despite the name)
///   progress=continue
/// terminated by `progress=end`.
struct ProgressParser {
    let totalSeconds: Double?

    /// Returns a fraction 0…1 for a single progress line, or nil if the line carries no update.
    func fraction(from line: String) -> Double? {
        guard let eq = line.firstIndex(of: "=") else { return nil }
        let key = String(line[line.startIndex..<eq])
        let value = String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces)

        if key == "progress" && value == "end" {
            return 1.0
        }

        guard let total = totalSeconds, total > 0 else { return nil }

        var currentSeconds: Double?
        switch key {
        case "out_time_us", "out_time_ms":
            // Both are reported in microseconds by modern ffmpeg.
            if let micro = Double(value) { currentSeconds = micro / 1_000_000 }
        case "out_time":
            currentSeconds = Self.parseTimestamp(value)
        default:
            return nil
        }

        guard let cur = currentSeconds else { return nil }
        return min(max(cur / total, 0), 1)
    }

    /// Parses "HH:MM:SS.micros" into seconds.
    static func parseTimestamp(_ ts: String) -> Double? {
        let parts = ts.split(separator: ":")
        guard parts.count == 3,
            let h = Double(parts[0]),
            let m = Double(parts[1]),
            let s = Double(parts[2])
        else { return nil }
        return h * 3600 + m * 60 + s
    }
}
