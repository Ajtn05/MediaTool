import Foundation

/// Queries `ffprobe` for the facts the UI and progress tracking need.
struct MediaProbe {
    struct Info {
        var durationSeconds: Double?
        var width: Int?
        var height: Int?
        var videoCodec: String?
        var audioCodec: String?

        /// Frame size, when the file actually has a video stream.
        var pixelSize: PixelSize? {
            guard let width, let height else { return nil }
            return PixelSize(width: width, height: height)
        }
    }

    let ffprobePath: String

    /// Runs ffprobe and parses its JSON output. Returns nil if ffprobe is unavailable or fails.
    func probe(_ url: URL) async -> Info? {
        let args = [
            "-v", "error",
            "-show_entries", "format=duration:stream=codec_type,codec_name,width,height",
            "-of", "json",
            url.path,
        ]

        // ffprobe writes its report to stdout; accumulate every stdout line.
        let collector = LineCollector()
        guard
            let result = try? await ProcessRunner.run(
                executable: ffprobePath,
                arguments: args,
                onProgressLine: { collector.append($0) }
            ), result.exitCode == 0
        else {
            return nil
        }

        return Self.parse(json: collector.joined())
    }

    static func parse(json: String) -> Info? {
        guard let data = json.data(using: .utf8),
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        var info = Info()

        if let format = root["format"] as? [String: Any],
            let durationStr = format["duration"] as? String
        {
            info.durationSeconds = Double(durationStr)
        }

        if let streams = root["streams"] as? [[String: Any]] {
            for stream in streams {
                let type = stream["codec_type"] as? String
                let codec = stream["codec_name"] as? String
                if type == "video" {
                    if info.videoCodec == nil { info.videoCodec = codec }
                    if let w = stream["width"] as? Int { info.width = w }
                    if let h = stream["height"] as? Int { info.height = h }
                } else if type == "audio" {
                    if info.audioCodec == nil { info.audioCodec = codec }
                }
            }
        }

        return info
    }
}

/// Simple thread-safe line accumulator for capturing a tool's full stdout.
private final class LineCollector {
    private var lines: [String] = []
    private let lock = NSLock()
    func append(_ line: String) {
        lock.lock()
        lines.append(line)
        lock.unlock()
    }
    func joined() -> String {
        lock.lock()
        defer { lock.unlock() }
        return lines.joined(separator: "\n")
    }
}
