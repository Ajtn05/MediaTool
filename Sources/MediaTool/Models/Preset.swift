import Foundation

/// A saved bundle of settings for one mode.
struct Preset: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var mode: MediaKind
    var video: VideoSettings?
    var audio: AudioSettings?
    var image: ImageSettings?
    /// Built-in presets can't be deleted.
    var builtIn: Bool = false
}
