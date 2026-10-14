import Foundation

enum JobState: Equatable {
    case queued
    case running
    case completed
    case cancelled
    case failed(String)

    var isTerminal: Bool {
        switch self {
        case .completed, .cancelled, .failed: return true
        case .queued, .running: return false
        }
    }
}

/// One unit of work in the queue. Observable so its row updates live during conversion.
final class Job: ObservableObject, Identifiable {
    let id = UUID()
    /// One entry for normal jobs; several when combining inputs (e.g. images → PDF).
    let inputURLs: [URL]
    let outputURL: URL
    let settings: JobSettings
    /// The full argument vector (tool + args) for display and execution.
    let command: [String]
    /// Total input duration in seconds, when known (video/audio) — used for progress.
    let durationSeconds: Double?
    /// True when `outputURL` is a filename *pattern* producing many files (frame extraction).
    let outputsMultipleFiles: Bool
    /// Optional label overriding the row title (e.g. "12 clips → joined.mp4").
    let displayName: String?

    @Published var state: JobState = .queued
    @Published var progress: Double = 0  // 0…1; indeterminate for images/unknown duration

    init(
        inputURLs: [URL],
        outputURL: URL,
        settings: JobSettings,
        command: [String],
        durationSeconds: Double?,
        outputsMultipleFiles: Bool = false,
        displayName: String? = nil
    ) {
        self.inputURLs = inputURLs
        self.outputURL = outputURL
        self.settings = settings
        self.command = command
        self.durationSeconds = durationSeconds
        self.outputsMultipleFiles = outputsMultipleFiles
        self.displayName = displayName
    }

    /// Convenience for the common single-input case.
    convenience init(
        inputURL: URL,
        outputURL: URL,
        settings: JobSettings,
        command: [String],
        durationSeconds: Double?
    ) {
        self.init(
            inputURLs: [inputURL], outputURL: outputURL,
            settings: settings, command: command, durationSeconds: durationSeconds)
    }

    var inputURL: URL { inputURLs.first ?? outputURL }

    /// What "Reveal in Finder" should select — the folder when the job wrote many files.
    var revealURL: URL {
        outputsMultipleFiles ? outputURL.deletingLastPathComponent() : outputURL
    }

    var title: String {
        displayName
            ?? (outputsMultipleFiles
                ? outputURL.deletingLastPathComponent().lastPathComponent
                : outputURL.lastPathComponent)
    }

    var kind: MediaKind { settings.kind }
}
