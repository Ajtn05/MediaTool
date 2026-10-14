import Foundation

/// Persists user presets to UserDefaults and provides built-in starters.
@MainActor
final class PresetStore: ObservableObject {
    @Published private(set) var presets: [Preset] = []

    private let key = "mediatool.presets.v1"

    init() {
        load()
    }

    func presets(for mode: MediaKind) -> [Preset] {
        presets.filter { $0.mode == mode }
    }

    /// Saves the current settings from `app` under a name for the active mode.
    func save(name: String, from app: AppState) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var preset = Preset(name: trimmed, mode: app.mode)
        switch app.mode {
        case .video: preset.video = app.video
        case .audio: preset.audio = app.audio
        case .image: preset.image = app.image
        }
        // Replace an existing user preset with the same name/mode, else append.
        if let idx = presets.firstIndex(where: { $0.mode == app.mode && $0.name == trimmed && !$0.builtIn }) {
            presets[idx] = preset
        } else {
            presets.append(preset)
        }
        persist()
    }

    func apply(_ preset: Preset, to app: AppState) {
        switch preset.mode {
        case .video: if let v = preset.video { app.video = v }
        case .audio: if let a = preset.audio { app.audio = a }
        case .image: if let i = preset.image { app.image = i }
        }
    }

    func delete(_ preset: Preset) {
        guard !preset.builtIn else { return }
        presets.removeAll { $0.id == preset.id }
        persist()
    }

    // MARK: Persistence

    private func persist() {
        let userPresets = presets.filter { !$0.builtIn }
        if let data = try? JSONEncoder().encode(userPresets) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        var loaded = Self.builtIns
        if let data = UserDefaults.standard.data(forKey: key),
            let user = try? JSONDecoder().decode([Preset].self, from: data)
        {
            loaded.append(contentsOf: user)
        }
        presets = loaded
    }

    // MARK: Built-in starters

    static var builtIns: [Preset] {
        var web1080 = VideoSettings()
        web1080.codec = .h264
        web1080.container = .mp4
        web1080.resolution = .fhd
        web1080.crf = 22
        web1080.audio = .aac
        web1080.audioBitrate = .k192

        var smallH265 = VideoSettings()
        smallH265.codec = .hevc
        smallH265.container = .mp4
        smallH265.resolution = .fhd
        smallH265.crf = 28

        var podcast = AudioSettings()
        podcast.format = .mp3
        podcast.bitrate = .k192
        podcast.normalize = true
        podcast.channels = .mono

        var lossless = AudioSettings()
        lossless.format = .flac

        var webp = ImageSettings()
        webp.format = .webp
        webp.quality = 82

        var thumb = ImageSettings()
        thumb.format = .jpg
        thumb.quality = 80
        thumb.resize = .maxDimension
        thumb.maxDimension = 640

        return [
            Preset(name: "Web 1080p (H.264)", mode: .video, video: web1080, builtIn: true),
            Preset(name: "Small H.265", mode: .video, video: smallH265, builtIn: true),
            Preset(name: "Podcast (MP3, normalized)", mode: .audio, audio: podcast, builtIn: true),
            Preset(name: "Lossless FLAC", mode: .audio, audio: lossless, builtIn: true),
            Preset(name: "WebP 82%", mode: .image, image: webp, builtIn: true),
            Preset(name: "Thumbnail 640 JPG", mode: .image, image: thumb, builtIn: true),
        ]
    }
}
