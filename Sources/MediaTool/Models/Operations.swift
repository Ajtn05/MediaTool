import Foundation

/// What a mode is doing. Most operations are 1 input → 1 output ("convert"), but some change
/// that arity: `join`/`contactSheet` take many inputs, `extractFrames`/`multiSize` emit many files.
enum VideoOperation: String, CaseIterable, Identifiable, Codable {
    case convert = "Convert"
    case extractFrames = "Frames"
    case join = "Join"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .convert: return "arrow.triangle.2.circlepath"
        case .extractFrames: return "photo.stack"
        case .join: return "arrow.trianglehead.merge"
        }
    }
    /// True when the operation consumes every staged file in one command.
    var combinesInputs: Bool { self == .join }
}

enum ImageOperation: String, CaseIterable, Identifiable, Codable {
    case convert = "Convert"
    case contactSheet = "Sheet"
    case multiSize = "Sizes"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .convert: return "arrow.triangle.2.circlepath"
        case .contactSheet: return "square.grid.3x3"
        case .multiSize: return "square.resize"
        }
    }
    var combinesInputs: Bool { self == .contactSheet }
}

// MARK: - Operation settings

/// How to pull stills out of a video.
struct FrameExtractSettings: Codable, Equatable {
    enum Mode: String, CaseIterable, Identifiable, Codable {
        case everySeconds = "Every N seconds"
        case everyNthFrame = "Every Nth frame"
        case singleFrame = "Single frame at time"
        var id: String { rawValue }
    }
    var mode: Mode = .everySeconds
    var seconds: Double = 1
    var nthFrame: Int = 30
    var timestamp: String = "00:00:01"
    var format: ImageFormat = .png
    var quality: Double = 92
}

struct JoinSettings: Codable, Equatable {
    var container: VideoContainer = .mp4
    var codec: VideoCodec = .h264
    var crf: Double = 23
    var speed: EncoderSpeed = .medium
    /// The concat filter needs an audio stream in *every* input; turn this off if any clip is silent.
    var includeAudio: Bool = true
    var audioBitrate: AudioBitrate = .k192
}

struct ContactSheetSettings: Codable, Equatable {
    var columns: Int = 4
    var cellSize: Int = 240
    var padding: Int = 6
    var showLabels: Bool = true
    var backgroundHex: String = "#F4F1EA"
    var format: ImageFormat = .jpg
    var quality: Double = 88
}

/// One-input → many-sizes export (app icons, favicons, @1x/@2x/@3x).
struct MultiSizeSettings: Codable, Equatable {
    var sizes: [Int] = [16, 32, 128, 256, 512, 1024]
    var format: ImageFormat = .png
    var quality: Double = 90

    static let commonSizes = [16, 32, 48, 64, 128, 180, 192, 256, 512, 1024]
}

/// Playback-rate change shared by video and audio convert.
struct SpeedSettings: Codable, Equatable {
    var enabled: Bool = false
    /// 0.25×…4×. 1.0 is unchanged.
    var rate: Double = 1.0
}

/// Anamorphic de-squeeze for video convert.
///
/// `factor` is the horizontal stretch that restores the true picture: an image squeezed by a
/// 1.33× adapter is un-squeezed with 1.33. Values below 1 narrow a frame that is too wide.
struct DesqueezeSettings: Codable, Equatable {
    enum Mode: String, CaseIterable, Identifiable, Codable {
        case none = "Off"
        /// Rewrite the display aspect ratio only — instant, lossless, survives "Copy".
        case tag = "Tag"
        /// Actually resample the pixels, baking the correct shape into the frames.
        case rescale = "Rescale"
        var id: String { rawValue }
    }
    var mode: Mode = .none
    /// 0.5…2.5. 1.0 is unchanged.
    var factor: Double = 1.33

    var isActive: Bool { mode != .none && factor != 1 }

    /// Common adapter/lens ratios, offered as one-click buttons.
    static let commonFactors: [Double] = [1.33, 1.5, 1.8, 2.0]
}

/// A single logo composited onto the image. Position is normalised 0…1 over the space the logo
/// *can* occupy, so it stays put across images of different sizes: 0 = flush to the left/top edge,
/// 1 = flush right/bottom, 0.5 = centred.
struct WatermarkSettings: Codable, Equatable {
    var enabled: Bool = false
    /// Absolute path to the logo; empty means none chosen yet.
    var logoPath: String = ""
    var normX: Double = 0.94
    var normY: Double = 0.94
    /// Logo width as a percentage of the finished image's width.
    var scalePercent: Double = 18
    var opacity: Double = 85  // 0…100

    var logoURL: URL? {
        logoPath.isEmpty ? nil : URL(fileURLWithPath: logoPath)
    }
}

/// Pixel dimensions, kept free of CoreGraphics so the command builder stays pure Foundation.
struct PixelSize: Equatable {
    var width: Int
    var height: Int
}

/// Border / canvas padding for image convert.
struct BorderSettings: Codable, Equatable {
    enum Mode: String, CaseIterable, Identifiable, Codable {
        case none = "None"
        case border = "Border"
        case padToCanvas = "Pad to canvas"
        var id: String { rawValue }
    }
    var mode: Mode = .none
    var thickness: Int = 24
    var canvasWidth: Int = 1080
    var canvasHeight: Int = 1080
    var colorHex: String = "#FFFFFF"
}
