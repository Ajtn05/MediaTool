import AppKit
import SwiftUI

/// Renders a small live preview of the current image settings by running the *real* ImageMagick
/// pipeline on a downscaled copy — so what you see matches what you'll get, rather than an
/// approximation drawn with different code.
@MainActor
final class PreviewService: ObservableObject {
    @Published private(set) var original: NSImage?
    @Published private(set) var rendered: NSImage?
    @Published private(set) var isRendering = false
    @Published private(set) var errorMessage: String?

    /// Longest edge of the preview render. Small enough to stay responsive while dragging sliders.
    private let previewSize = 520

    private var currentSourceURL: URL?
    private var renderTask: Task<Void, Never>?
    private let scratch: URL

    init() {
        // Per-instance subdirectory. A shared fixed path breaks when the view tree is re-keyed
        // (the accent switcher does exactly that): SwiftUI builds the replacement before
        // releasing the old one, whose deinit would then delete the directory the new instance
        // is about to write into — every render failing with "WriteBlob Failed".
        scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("MediaToolPreview", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: scratch)
    }

    /// Loads (or clears) the source thumbnail shown as "before".
    func setSource(_ url: URL?) {
        guard url != currentSourceURL else { return }
        currentSourceURL = url
        rendered = nil
        errorMessage = nil

        guard let url else {
            original = nil
            return
        }
        original = NSImage(contentsOf: url)
    }

    /// Re-renders the preview. Debounced, and supersedes any in-flight render.
    func requestRender(
        settings: ImageSettings,
        magickPath: String?,
        watermark: CommandBuilder.WatermarkPlacement? = nil
    ) {
        guard let source = currentSourceURL, let magickPath else { return }

        renderTask?.cancel()
        renderTask = Task { [weak self] in
            // Coalesce rapid slider movement into one render.
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled, let self else { return }
            await self.render(
                source: source, settings: settings,
                magickPath: magickPath, watermark: watermark)
        }
    }

    private func render(
        source: URL,
        settings: ImageSettings,
        magickPath: String,
        watermark: CommandBuilder.WatermarkPlacement?
    ) async {
        isRendering = true
        defer { isRendering = false }

        // Cheap insurance: the scratch dir lives in /tmp and can be reaped by the system.
        try? FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)

        // Always emit PNG: the preview only needs to show the pixels, and formats like PDF or
        // AVIF would either need extra tools or be slow to encode.
        let output = scratch.appendingPathComponent("preview-\(UUID().uuidString).png")

        var previewSettings = settings
        previewSettings.format = .png

        var args = CommandBuilder.imageArgs(
            input: source, output: output,
            settings: previewSettings, watermark: watermark)
        // Downscale *last*, just before the output path: crop offsets and border thickness are in
        // source pixels, so shrinking first would misplace them relative to the real conversion.
        args.insert(contentsOf: ["-resize", "\(previewSize)x\(previewSize)>"], at: args.count - 1)

        defer { try? FileManager.default.removeItem(at: output) }

        do {
            let result = try await ProcessRunner.run(executable: magickPath, arguments: args)
            guard !Task.isCancelled else { return }

            if result.exitCode == 0, let image = NSImage(contentsOf: output) {
                rendered = image
                errorMessage = nil
            } else {
                errorMessage =
                    result.stderrTail
                    .split(separator: "\n").last.map(String.init) ?? "Preview failed"
            }
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }
}
