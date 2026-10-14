import Foundation

// MARK: - Settings snapshots

struct VideoSettings: Codable, Equatable {
    var container: VideoContainer = .mp4
    var codec: VideoCodec = .h264
    var useHardware: Bool = false  // VideoToolbox (H.264/HEVC only), bitrate-driven
    var useBitrate: Bool = false  // false = CRF quality, true = target bitrate
    var crf: Double = VideoCodec.h264.defaultCRF
    var bitrateMbps: Double = 8
    var speed: EncoderSpeed = .medium
    var resolution: ResolutionPreset = .original
    var customWidth: Int = 1920
    var customHeight: Int = 1080
    var framerate: FrameratePreset = .original
    var customFramerate: Double = 30
    var audio: AudioTrack = .aac
    var audioBitrate: AudioBitrate = .k192

    // Trim
    var trimEnabled: Bool = false
    var trimStart: String = "00:00:00"
    var trimEnd: String = "00:00:10"

    // Transform
    var rotation: Rotation = .none
    var flipH: Bool = false
    var flipV: Bool = false
    var cropEnabled: Bool = false
    var cropX: Int = 0
    var cropY: Int = 0
    var cropW: Int = 1280
    var cropH: Int = 720

    // Playback rate (distinct from `speed`, which is the encoder effort preset)
    var playbackSpeed = SpeedSettings()

    // Anamorphic de-squeeze. Held as an Optional so presets saved before this setting existed
    // still decode — synthesized Codable treats a missing key as an error, not as "use the
    // default". The accessor below hides that from every call site.
    private var storedDesqueeze: DesqueezeSettings?
    var desqueeze: DesqueezeSettings {
        get { storedDesqueeze ?? DesqueezeSettings() }
        set { storedDesqueeze = newValue }
    }
}

struct AudioSettings: Codable, Equatable {
    var format: AudioFormat = .mp3
    var bitrate: AudioBitrate = .k256

    // Trim
    var trimEnabled: Bool = false
    var trimStart: String = "00:00:00"
    var trimEnd: String = "00:00:10"

    // Processing
    var normalize: Bool = false
    var gainEnabled: Bool = false
    var gainDB: Double = 0
    var sampleRate: SampleRate = .original
    var channels: ChannelLayout = .original

    // Playback rate
    var playbackSpeed = SpeedSettings()
}

struct ImageSettings: Codable, Equatable {
    var format: ImageFormat = .webp
    var resize: ImageResizeMode = .none
    var maxDimension: Int = 1920
    var percent: Double = 50
    var exactWidth: Int = 1920
    var exactHeight: Int = 1080
    var keepAspect: Bool = true  // for exact mode
    var quality: Double = 82  // 0…100 for lossy formats

    /// Multiplier for the `.factor` resize mode — 0.5 halves every image, 2 doubles it. Held as an
    /// Optional so presets saved before this setting existed still decode: synthesized Codable
    /// treats a missing key as an error, not as "use the default". The accessor hides that, and
    /// clamps to a sane range so the builder can never emit a 0% or negative resize.
    private var storedScaleFactor: Double?
    var scaleFactor: Double {
        get { storedScaleFactor ?? 0.5 }
        set { storedScaleFactor = newValue.isFinite ? min(max(newValue, 0.01), 20) : 1 }
    }

    /// One-click multipliers offered next to the factor slider.
    static let commonScaleFactors: [Double] = [0.25, 0.5, 0.75, 1, 2, 4]

    // Transform
    var rotation: Rotation = .none
    var flipH: Bool = false
    var flipV: Bool = false
    var cropEnabled: Bool = false
    var cropX: Int = 0
    var cropY: Int = 0
    var cropW: Int = 800
    var cropH: Int = 600

    // Adjustments (0 = no change; range −100…100)
    var brightness: Double = 0
    var contrast: Double = 0
    var saturation: Double = 0
    var grayscale: Bool = false
    var stripMetadata: Bool = false

    // Border / canvas padding
    var border = BorderSettings()

    // Logo overlay
    var watermark = WatermarkSettings()
}

/// A frozen copy of whichever settings apply to a job, captured at enqueue time.
enum JobSettings {
    case video(VideoSettings)
    case audio(AudioSettings)
    case image(ImageSettings)

    var kind: MediaKind {
        switch self {
        case .video: return .video
        case .audio: return .audio
        case .image: return .image
        }
    }
}
