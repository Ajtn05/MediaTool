import Foundation

/// Target vertical resolution. `nil` height means "keep original".
enum ResolutionPreset: String, CaseIterable, Identifiable, Codable {
    case original = "Original"
    case uhd = "2160p (4K)"
    case qhd = "1440p"
    case fhd = "1080p"
    case hd = "720p"
    case sd = "480p"
    case custom = "Custom…"

    var id: String { rawValue }

    /// Target height in pixels, or nil for original/custom.
    var height: Int? {
        switch self {
        case .original, .custom: return nil
        case .uhd: return 2160
        case .qhd: return 1440
        case .fhd: return 1080
        case .hd: return 720
        case .sd: return 480
        }
    }
}

enum FrameratePreset: String, CaseIterable, Identifiable, Codable {
    case original = "Original"
    case fps60 = "60"
    case fps30 = "30"
    case fps24 = "24"
    case custom = "Custom…"

    var id: String { rawValue }

    var value: Double? {
        switch self {
        case .original, .custom: return nil
        case .fps60: return 60
        case .fps30: return 30
        case .fps24: return 24
        }
    }
}

/// Where converted files are written.
enum OutputDestination: String, CaseIterable, Identifiable, Codable {
    case sameAsSource = "Same folder as source"
    case customFolder = "Choose folder…"
    var id: String { rawValue }
}

/// How output filenames are derived.
enum NamingMode: String, CaseIterable, Identifiable, Codable {
    /// Keep the source name and append a suffix — `photo.png` → `photo-converted.webp`.
    case suffix = "Keep name + suffix"
    /// Replace the name entirely — `photo.png` → `holiday.webp` (numbered when batching).
    case rename = "Rename to"
    var id: String { rawValue }
}
