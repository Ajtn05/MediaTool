import Foundation

// MARK: - Video

/// Output container for video jobs. `ext` is also the ffmpeg-inferred muxer.
enum VideoContainer: String, CaseIterable, Identifiable, Codable {
    case mp4 = "MP4"
    case mkv = "MKV"
    case mov = "MOV"
    case webm = "WebM"

    var id: String { rawValue }
    var ext: String {
        switch self {
        case .mp4: return "mp4"
        case .mkv: return "mkv"
        case .mov: return "mov"
        case .webm: return "webm"
        }
    }
}

enum VideoCodec: String, CaseIterable, Identifiable, Codable {
    case h264 = "H.264"
    case hevc = "H.265 / HEVC"
    case vp9 = "VP9"
    case av1 = "AV1"
    case copy = "Copy (no re-encode)"

    var id: String { rawValue }

    /// The ffmpeg `-c:v` value, or nil when copying.
    var encoder: String? {
        switch self {
        case .h264: return "libx264"
        case .hevc: return "libx265"
        case .vp9: return "libvpx-vp9"
        case .av1: return "libsvtav1"
        case .copy: return nil
        }
    }

    var isCopy: Bool { self == .copy }

    /// Whether this encoder is driven by a CRF-style quality value.
    var usesCRF: Bool { self != .copy }

    /// Sensible CRF range and default per codec (lower = higher quality).
    var crfRange: ClosedRange<Double> {
        switch self {
        case .h264, .hevc: return 0...51
        case .vp9: return 0...63
        case .av1: return 0...63
        case .copy: return 0...0
        }
    }
    var defaultCRF: Double {
        switch self {
        case .h264: return 23
        case .hevc: return 28
        case .vp9: return 31
        case .av1: return 30
        case .copy: return 0
        }
    }

    /// Containers this codec can legally live in.
    var compatibleContainers: [VideoContainer] {
        switch self {
        case .h264: return [.mp4, .mkv, .mov]
        case .hevc: return [.mp4, .mkv, .mov]
        case .vp9: return [.webm, .mkv]
        case .av1: return [.mp4, .mkv, .webm]
        case .copy: return VideoContainer.allCases
        }
    }
}

/// x264/x265-style speed presets. VP9/AV1 map these onto their own scales in CommandBuilder.
enum EncoderSpeed: String, CaseIterable, Identifiable, Codable {
    case ultrafast, superfast, veryfast, faster, fast, medium, slow, slower, veryslow
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

enum AudioTrack: String, CaseIterable, Identifiable, Codable {
    case aac = "AAC"
    case opus = "Opus"
    case mp3 = "MP3"
    case copy = "Copy"
    case none = "None (strip)"

    var id: String { rawValue }
    var encoder: String? {
        switch self {
        case .aac: return "aac"
        case .opus: return "libopus"
        case .mp3: return "libmp3lame"
        case .copy, .none: return nil
        }
    }
    var isStripped: Bool { self == .none }
    var isCopy: Bool { self == .copy }
}

// MARK: - Audio

/// Output format for standalone audio jobs.
enum AudioFormat: String, CaseIterable, Identifiable, Codable {
    case mp3 = "MP3"
    case m4a = "M4A / AAC"
    case wav = "WAV"
    case flac = "FLAC"
    case opus = "Opus"

    var id: String { rawValue }
    var ext: String {
        switch self {
        case .mp3: return "mp3"
        case .m4a: return "m4a"
        case .wav: return "wav"
        case .flac: return "flac"
        case .opus: return "opus"
        }
    }
    var encoder: String {
        switch self {
        case .mp3: return "libmp3lame"
        case .m4a: return "aac"
        case .wav: return "pcm_s16le"
        case .flac: return "flac"
        case .opus: return "libopus"
        }
    }
    /// Lossy formats expose a bitrate control.
    var isLossy: Bool {
        switch self {
        case .mp3, .m4a, .opus: return true
        case .wav, .flac: return false
        }
    }
}

enum AudioBitrate: Int, CaseIterable, Identifiable, Codable {
    case k128 = 128
    case k192 = 192
    case k256 = 256
    case k320 = 320
    var id: Int { rawValue }
    var label: String { "\(rawValue) kbps" }
    var argument: String { "\(rawValue)k" }
}

// MARK: - Image

enum ImageFormat: String, CaseIterable, Identifiable, Codable {
    case png = "PNG"
    case jpg = "JPG"
    case webp = "WebP"
    case avif = "AVIF"
    case heic = "HEIC"
    case tiff = "TIFF"
    case gif = "GIF"
    case bmp = "BMP"
    case pdf = "PDF (combine)"

    var id: String { rawValue }
    var ext: String {
        switch self {
        case .png: return "png"
        case .jpg: return "jpg"
        case .webp: return "webp"
        case .avif: return "avif"
        case .heic: return "heic"
        case .tiff: return "tiff"
        case .gif: return "gif"
        case .bmp: return "bmp"
        case .pdf: return "pdf"
        }
    }
    /// Formats where a quality (compression) value is meaningful.
    var usesQuality: Bool {
        switch self {
        case .jpg, .webp, .avif, .heic, .pdf: return true
        case .png, .tiff, .gif, .bmp: return false
        }
    }
    /// PDF combines all staged images into one multi-page document.
    var combinesIntoOne: Bool { self == .pdf }
}

// MARK: - Shared transform / processing enums

enum Rotation: Int, CaseIterable, Identifiable, Codable {
    case none = 0
    case r90 = 90
    case r180 = 180
    case r270 = 270
    var id: Int { rawValue }
    var label: String { self == .none ? "None" : "\(rawValue)°" }
}

enum SampleRate: Int, CaseIterable, Identifiable, Codable {
    case original = 0
    case r22050 = 22050
    case r44100 = 44100
    case r48000 = 48000
    case r96000 = 96000
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .original: return "Original"
        case .r22050: return "22.05 kHz"
        case .r44100: return "44.1 kHz"
        case .r48000: return "48 kHz"
        case .r96000: return "96 kHz"
        }
    }
}

enum ChannelLayout: Int, CaseIterable, Identifiable, Codable {
    case original = 0
    case mono = 1
    case stereo = 2
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .original: return "Original"
        case .mono: return "Mono"
        case .stereo: return "Stereo"
        }
    }
}

enum ImageResizeMode: String, CaseIterable, Identifiable, Codable {
    case none = "Original size"
    case maxDimension = "Fit within (max side)"
    case percent = "Scale by percent"
    case factor = "Scale by factor (×)"
    case exact = "Exact width × height"
    var id: String { rawValue }
}
