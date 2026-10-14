import Foundation
import UniformTypeIdentifiers

/// The three conversion domains the app supports, matching the top-level mode switcher.
enum MediaKind: String, CaseIterable, Identifiable, Codable {
    case video = "Video"
    case audio = "Audio"
    case image = "Image"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .video: return "film"
        case .audio: return "waveform"
        case .image: return "photo"
        }
    }

    /// Best-effort classification of a file by its uniform type, falling back to its extension.
    static func detect(for url: URL) -> MediaKind? {
        if let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
            if type.conforms(to: .movie) || type.conforms(to: .video) { return .video }
            if type.conforms(to: .audio) { return .audio }
            if type.conforms(to: .image) { return .image }
        }
        return detect(byExtension: url.pathExtension)
    }

    static func detect(byExtension ext: String) -> MediaKind? {
        let e = ext.lowercased()
        if videoExtensions.contains(e) { return .video }
        if audioExtensions.contains(e) { return .audio }
        if imageExtensions.contains(e) { return .image }
        return nil
    }

    static let videoExtensions: Set<String> = [
        "mp4", "mkv", "mov", "webm", "avi", "m4v", "wmv", "flv", "mpg", "mpeg", "ts", "m2ts", "3gp",
    ]
    static let audioExtensions: Set<String> = [
        "mp3", "aac", "m4a", "wav", "flac", "opus", "ogg", "aiff", "aif", "wma", "alac",
    ]
    static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "webp", "avif", "heic", "heif", "tiff", "tif", "gif", "bmp",
    ]
}
