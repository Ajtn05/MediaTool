import Foundation

/// Locates the external command-line tools the app drives. GUI apps launched from Finder
/// inherit a minimal PATH, so we probe well-known Homebrew locations first and always
/// spawn tools by absolute path.
final class ToolLocator: ObservableObject {
    struct Tools {
        var ffmpeg: String?
        var ffprobe: String?
        var magick: String?
        var ghostscript: String?  // required by ImageMagick to WRITE PDFs
    }

    @Published private(set) var tools = Tools()

    /// Directories to search, in priority order, ahead of the inherited PATH.
    private static let searchDirs = [
        "/opt/homebrew/bin",  // Apple Silicon Homebrew
        "/usr/local/bin",  // Intel Homebrew
        "/opt/local/bin",  // MacPorts
        "/usr/bin",
    ]

    init() {
        refresh()
    }

    func refresh() {
        tools = Tools(
            ffmpeg: Self.locate("ffmpeg"),
            ffprobe: Self.locate("ffprobe"),
            magick: Self.locate("magick") ?? Self.locate("convert"),
            ghostscript: Self.locate("gs")
        )
    }

    var hasFFmpeg: Bool { tools.ffmpeg != nil && tools.ffprobe != nil }
    var hasMagick: Bool { tools.magick != nil }
    var hasGhostscript: Bool { tools.ghostscript != nil }

    /// Homebrew's ImageMagick ships with no font configuration on macOS, so `montage` fails
    /// (exit 1) the moment it tries to draw a label — which it does *by default*. We therefore
    /// always hand it an explicit font file.
    static let labelFontPath: String? = {
        let candidates = [
            "/System/Library/Fonts/Supplemental/Arial.ttf",
            "/System/Library/Fonts/Helvetica.ttc",
            "/System/Library/Fonts/SFNS.ttf",
            "/Library/Fonts/Arial.ttf",
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0) }
    }()

    /// Returns the tools missing for a given mode, so the UI can prompt to install them.
    func missing(for kind: MediaKind) -> [String] {
        switch kind {
        case .video, .audio:
            return hasFFmpeg ? [] : ["ffmpeg"]
        case .image:
            return hasMagick ? [] : ["imagemagick"]
        }
    }

    static func locate(_ name: String) -> String? {
        for dir in searchDirs {
            let path = dir + "/" + name
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        // Fall back to whatever PATH the process happens to have.
        if let path = which(name) { return path }
        return nil
    }

    private static func which(_ name: String) -> String? {
        guard let pathEnv = ProcessInfo.processInfo.environment["PATH"] else { return nil }
        for dir in pathEnv.split(separator: ":") {
            let candidate = String(dir) + "/" + name
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }
}
