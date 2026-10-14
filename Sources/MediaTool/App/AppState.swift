import Foundation
import ImageIO
import SwiftUI

/// Top-level view model: holds the current mode, per-mode settings, staged input files,
/// output preferences, and turns everything into jobs on the queue.
@MainActor
final class AppState: ObservableObject {
    @Published var mode: MediaKind = .video

    @Published var video = VideoSettings()
    @Published var audio = AudioSettings()
    @Published var image = ImageSettings()

    /// Which operation the current mode is performing.
    @Published var videoOp: VideoOperation = .convert
    @Published var imageOp: ImageOperation = .convert

    // Settings for the non-convert operations.
    @Published var frames = FrameExtractSettings()
    @Published var join = JoinSettings()
    @Published var sheet = ContactSheetSettings()
    @Published var multiSize = MultiSizeSettings()

    /// Files dropped/added but not yet converted, for the current session.
    @Published var stagedURLs: [URL] = []

    @Published var destination: OutputDestination = .sameAsSource
    @Published var customFolder: URL?
    @Published var naming: NamingMode = .suffix
    @Published var nameSuffix: String = "-converted"
    @Published var customName: String = "output"

    /// Non-fatal note shown to the user (e.g. files skipped because they didn't match the mode).
    @Published var notice: String?

    /// Cached probe results per input file, populated asynchronously on stage.
    @Published var probeInfo: [URL: ProbeDisplay] = [:]

    let tools: ToolLocator
    let queue: JobQueue

    init(tools: ToolLocator, queue: JobQueue) {
        self.tools = tools
        self.queue = queue
    }

    // MARK: Staging

    /// Whether a file is a valid input for the current mode.
    func accepts(_ url: URL) -> Bool {
        guard let kind = MediaKind.detect(for: url) else { return false }
        switch mode {
        case .video: return kind == .video
        case .audio: return kind == .video || kind == .audio
        case .image: return kind == .image
        }
    }

    func stage(_ urls: [URL]) {
        var added = 0
        var skipped = 0
        for url in urls {
            if accepts(url) {
                if !stagedURLs.contains(url) {
                    stagedURLs.append(url)
                    added += 1
                    Task { await probeFile(url) }
                }
            } else {
                skipped += 1
            }
        }
        if skipped > 0 {
            notice =
                "\(skipped) file\(skipped == 1 ? "" : "s") skipped — not valid for \(mode.rawValue) mode."
        } else if added > 0 {
            notice = nil
        }
    }

    func unstage(_ url: URL) {
        stagedURLs.removeAll { $0 == url }
    }

    func clearStaged() {
        stagedURLs.removeAll()
    }

    // MARK: Output path

    var outputExtension: String {
        switch mode {
        case .video:
            switch videoOp {
            case .convert: return video.container.ext
            case .extractFrames: return frames.format.ext
            case .join: return join.container.ext
            }
        case .audio:
            return audio.format.ext
        case .image:
            switch imageOp {
            case .convert: return image.format.ext
            case .contactSheet: return sheet.format.ext
            case .multiSize: return multiSize.format.ext
            }
        }
    }

    /// Computes a non-clobbering output URL for an input file.
    /// `index`/`total` drive numbering when renaming a batch (`holiday-1`, `holiday-2`, …).
    func outputURL(for input: URL, index: Int = 0, total: Int = 1) -> URL {
        let folder = outputFolder(for: input)
        let ext = outputExtension

        let stem: String
        switch naming {
        case .suffix:
            stem = input.deletingPathExtension().lastPathComponent + nameSuffix
        case .rename:
            let base = customName.trimmingCharacters(in: .whitespaces)
            let safe = base.isEmpty ? "output" : base
            // Renaming several files to one name would collide, so number them.
            stem = total > 1 ? "\(safe)-\(index + 1)" : safe
        }

        var candidate = folder.appendingPathComponent(stem).appendingPathExtension(ext)

        // Never overwrite the source file itself; bump with a counter if needed.
        var counter = 1
        while candidate.path == input.path {
            candidate =
                folder
                .appendingPathComponent("\(stem)-\(counter)")
                .appendingPathExtension(ext)
            counter += 1
        }
        return candidate
    }

    /// Folder that outputs are written to, given the current destination setting.
    private func outputFolder(for input: URL) -> URL {
        switch destination {
        case .sameAsSource: return input.deletingLastPathComponent()
        case .customFolder: return customFolder ?? input.deletingLastPathComponent()
        }
    }

    /// Output URL for a job that merges every input into one file (PDF, join, contact sheet).
    /// `basename` is the default; an explicit rename overrides it.
    func combinedOutputURL(basename: String, ext: String) -> URL {
        let first = stagedURLs.first ?? URL(fileURLWithPath: NSHomeDirectory())
        let folder = outputFolder(for: first)

        var stem = basename
        if naming == .rename {
            let trimmed = customName.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { stem = trimmed }
        }

        var candidate = folder.appendingPathComponent(stem).appendingPathExtension(ext)
        var counter = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(stem)-\(counter)").appendingPathExtension(ext)
            counter += 1
        }
        return candidate
    }

    /// Directory that frame extraction writes its stills into.
    func framesFolderURL(for input: URL) -> URL {
        let base = input.deletingPathExtension().lastPathComponent
        var candidate = outputFolder(for: input).appendingPathComponent("\(base)-frames")
        var counter = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = outputFolder(for: input).appendingPathComponent("\(base)-frames-\(counter)")
            counter += 1
        }
        return candidate
    }

    /// Whether the current image settings combine all inputs into a single output.
    var isCombiningPDF: Bool {
        mode == .image && imageOp == .convert && image.format.combinesIntoOne
    }

    /// True when the active operation consumes every staged file in one command.
    var combinesAllInputs: Bool {
        switch mode {
        case .video: return videoOp.combinesInputs
        case .audio: return false
        case .image: return imageOp.combinesInputs || isCombiningPDF
        }
    }

    /// Tools required for the current mode/settings that are not installed.
    func activeMissingTools() -> [String] {
        var missing = tools.missing(for: mode)
        if isCombiningPDF && !tools.hasGhostscript {
            missing.append("ghostscript")  // ImageMagick needs it to write PDFs
        }
        return missing
    }

    // MARK: Command preview (uses the first staged file, or a placeholder)

    func previewCommand() -> String {
        let input = stagedURLs.first ?? URL(fileURLWithPath: "input")
        let inputs = stagedURLs.isEmpty ? [input] : stagedURLs
        let magickName = tools.tools.magick.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "magick"
        let toolName: String
        let args: [String]

        switch mode {
        case .video:
            toolName = "ffmpeg"
            switch videoOp {
            case .convert:
                args = CommandBuilder.videoArgs(
                    input: input, output: outputURL(for: input),
                    settings: video, sourceSize: cachedSize(of: input))
            case .extractFrames:
                let pattern = framesFolderURL(for: input)
                    .appendingPathComponent("frame_%04d.\(frames.format.ext)")
                args = CommandBuilder.extractFramesArgs(
                    input: input, outputPattern: pattern, settings: frames)
            case .join:
                args = CommandBuilder.joinArgs(
                    inputs: inputs,
                    output: combinedOutputURL(basename: "joined", ext: join.container.ext),
                    settings: join)
            }
        case .audio:
            toolName = "ffmpeg"
            args = CommandBuilder.audioArgs(input: input, output: outputURL(for: input), settings: audio)
        case .image:
            toolName = magickName
            switch imageOp {
            case .convert:
                if isCombiningPDF {
                    args = CommandBuilder.imagePDFArgs(
                        inputs: inputs,
                        output: combinedOutputURL(basename: "combined", ext: "pdf"),
                        settings: image)
                } else {
                    args = CommandBuilder.imageArgs(
                        input: input, output: outputURL(for: input), settings: image,
                        watermark: watermarkPlacement(for: input))
                }
            case .contactSheet:
                args = CommandBuilder.contactSheetArgs(
                    inputs: inputs,
                    output: combinedOutputURL(basename: "contact-sheet", ext: sheet.format.ext),
                    settings: sheet,
                    fontPath: ToolLocator.labelFontPath)
            case .multiSize:
                let size = multiSize.sizes.first ?? 512
                args = CommandBuilder.multiSizeArgs(
                    input: input,
                    output: multiSizeOutputURL(for: input, size: size),
                    size: size,
                    settings: multiSize)
            }
        }
        return ([toolName] + args)
            .map { $0.contains(" ") ? "\"\($0)\"" : $0 }
            .joined(separator: " ")
    }

    /// Multi-size output is always `<stem>-<size>.<ext>` — the size *is* the distinguishing suffix.
    private func multiSizeOutputURL(for input: URL, size: Int) -> URL {
        var stem = input.deletingPathExtension().lastPathComponent
        if naming == .rename {
            let trimmed = customName.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { stem = trimmed }
        }
        return outputFolder(for: input)
            .appendingPathComponent("\(stem)-\(size)")
            .appendingPathExtension(multiSize.format.ext)
    }

    // MARK: Enqueue

    /// Builds jobs from staged files (probing durations as needed) and hands them to the queue.
    func convertStaged() async {
        guard !stagedURLs.isEmpty else { return }
        guard activeMissingTools().isEmpty else { return }

        let inputs = stagedURLs

        // --- Operations that collapse every input into a single job ---

        if mode == .video && videoOp == .join {
            let output = combinedOutputURL(basename: "joined", ext: join.container.ext)
            let args = CommandBuilder.joinArgs(inputs: inputs, output: output, settings: join)
            // Progress is measured against the summed duration of every clip.
            var total: Double = 0
            for input in inputs { total += await probeDuration(input) ?? 0 }
            let job = Job(
                inputURLs: inputs, outputURL: output,
                settings: .video(video),
                command: [tools.tools.ffmpeg!] + args,
                durationSeconds: total > 0 ? total : nil,
                displayName: "\(inputs.count) clips → \(output.lastPathComponent)")
            queue.add([job])
            clearStaged()
            return
        }

        if mode == .image && imageOp == .contactSheet {
            let output = combinedOutputURL(basename: "contact-sheet", ext: sheet.format.ext)
            let args = CommandBuilder.contactSheetArgs(
                inputs: inputs, output: output,
                settings: sheet,
                fontPath: ToolLocator.labelFontPath)
            let job = Job(
                inputURLs: inputs, outputURL: output,
                settings: .image(image),
                command: [tools.tools.magick!] + args,
                durationSeconds: nil,
                displayName: "\(inputs.count) images → \(output.lastPathComponent)")
            queue.add([job])
            clearStaged()
            return
        }

        if isCombiningPDF {
            let output = combinedOutputURL(basename: "combined", ext: "pdf")
            let args = CommandBuilder.imagePDFArgs(inputs: inputs, output: output, settings: image)
            let job = Job(
                inputURLs: inputs, outputURL: output,
                settings: .image(image),
                command: [tools.tools.magick!] + args,
                durationSeconds: nil,
                displayName: "\(inputs.count) images → \(output.lastPathComponent)")
            queue.add([job])
            clearStaged()
            return
        }

        // --- Per-input operations ---

        if mode == .video && videoOp == .extractFrames {
            var jobs: [Job] = []
            for input in inputs {
                let folder = framesFolderURL(for: input)
                try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let pattern = folder.appendingPathComponent("frame_%04d.\(frames.format.ext)")
                let args = CommandBuilder.extractFramesArgs(
                    input: input, outputPattern: pattern, settings: frames)
                jobs.append(
                    Job(
                        inputURLs: [input], outputURL: pattern,
                        settings: .video(video),
                        command: [tools.tools.ffmpeg!] + args,
                        durationSeconds: await probeDuration(input),
                        outputsMultipleFiles: true,
                        displayName: "\(input.lastPathComponent) → \(folder.lastPathComponent)/"))
            }
            queue.add(jobs)
            clearStaged()
            return
        }

        if mode == .image && imageOp == .multiSize {
            var jobs: [Job] = []
            for input in inputs {
                for size in multiSize.sizes.sorted() {
                    let output = multiSizeOutputURL(for: input, size: size)
                    let args = CommandBuilder.multiSizeArgs(
                        input: input, output: output,
                        size: size, settings: multiSize)
                    jobs.append(
                        Job(
                            inputURL: input, outputURL: output,
                            settings: .image(image),
                            command: [tools.tools.magick!] + args,
                            durationSeconds: nil))
                }
            }
            queue.add(jobs)
            clearStaged()
            return
        }

        var newJobs: [Job] = []

        for (index, input) in inputs.enumerated() {
            let output = outputURL(for: input, index: index, total: inputs.count)
            let job: Job
            switch mode {
            case .video:
                // Probed here rather than read from the cache so a file converted the instant it
                // was dropped still gets its de-squeeze tag.
                let info = await probeMedia(input)
                let args = CommandBuilder.videoArgs(
                    input: input, output: output,
                    settings: video, sourceSize: info?.pixelSize)
                job = Job(
                    inputURL: input, outputURL: output,
                    settings: .video(video),
                    command: [tools.tools.ffmpeg!] + args,
                    durationSeconds: info?.durationSeconds)
            case .audio:
                let args = CommandBuilder.audioArgs(input: input, output: output, settings: audio)
                let duration = await probeDuration(input)
                job = Job(
                    inputURL: input, outputURL: output,
                    settings: .audio(audio),
                    command: [tools.tools.ffmpeg!] + args,
                    durationSeconds: duration)
            case .image:
                let args = CommandBuilder.imageArgs(
                    input: input, output: output, settings: image,
                    watermark: watermarkPlacement(for: input))
                job = Job(
                    inputURL: input, outputURL: output,
                    settings: .image(image),
                    command: [tools.tools.magick!] + args,
                    durationSeconds: nil)
            }
            newJobs.append(job)
        }

        queue.add(newJobs)
        clearStaged()
    }

    private func probeMedia(_ url: URL) async -> MediaProbe.Info? {
        guard let ffprobe = tools.tools.ffprobe else { return nil }
        return await MediaProbe(ffprobePath: ffprobe).probe(url)
    }

    private func probeDuration(_ url: URL) async -> Double? {
        await probeMedia(url)?.durationSeconds
    }

    /// Frame size from the staged-file probe cache. Used by the command preview and the
    /// de-squeeze readout, both of which run on the main actor and can't await a probe.
    func cachedSize(of url: URL) -> PixelSize? {
        guard let info = probeInfo[url], let w = info.width, let h = info.height else { return nil }
        return PixelSize(width: w, height: h)
    }

    // MARK: Watermark

    /// Reads pixel dimensions without decoding the image. Synchronous and cheap, so watermark
    /// placement doesn't have to wait on the async ffprobe cache.
    static func pixelSize(of url: URL) -> PixelSize? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let w = props[kCGImagePropertyPixelWidth] as? Int,
            let h = props[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        return PixelSize(width: w, height: h)
    }

    /// Turns the normalised watermark settings into concrete pixels for one input image.
    /// Returns nil when disabled, unset, or if either file can't be read.
    func watermarkPlacement(for input: URL) -> CommandBuilder.WatermarkPlacement? {
        let wm = image.watermark
        guard wm.enabled, let logoURL = wm.logoURL,
            FileManager.default.fileExists(atPath: logoURL.path),
            let source = Self.pixelSize(of: input),
            let logo = Self.pixelSize(of: logoURL), logo.width > 0
        else { return nil }

        let final = CommandBuilder.finalDimensions(source: source, settings: image)
        let logoW = max(1, Int((Double(final.width) * wm.scalePercent / 100).rounded()))
        let logoH = max(1, Int((Double(logoW) * Double(logo.height) / Double(logo.width)).rounded()))

        // Normalised position spans the space the logo can actually occupy.
        let freeX = max(0, final.width - logoW)
        let freeY = max(0, final.height - logoH)

        return CommandBuilder.WatermarkPlacement(
            logo: logoURL,
            widthPx: logoW,
            offsetX: Int((Double(freeX) * min(max(wm.normX, 0), 1)).rounded()),
            offsetY: Int((Double(freeY) * min(max(wm.normY, 0), 1)).rounded()),
            opacity: min(max(wm.opacity / 100, 0), 1)
        )
    }

    // MARK: Input info

    /// Probes a file's metadata + size and caches a display summary.
    private func probeFile(_ url: URL) async {
        var display = ProbeDisplay()
        display.sizeBytes =
            (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? nil

        if let ffprobe = tools.tools.ffprobe {
            let info = await MediaProbe(ffprobePath: ffprobe).probe(url)
            display.width = info?.width
            display.height = info?.height
            display.duration = info?.durationSeconds
            display.codec = info?.videoCodec ?? info?.audioCodec
        }
        probeInfo[url] = display
    }

    /// Estimated output size in bytes — only where it's deterministic (bitrate video, lossy audio).
    func estimatedOutputBytes(for url: URL) -> Int64? {
        guard let duration = probeInfo[url]?.duration, duration > 0 else { return nil }
        switch mode {
        case .video:
            // Only meaningful when a target video bitrate is in effect.
            let bitrateMode = video.useBitrate || CommandBuilder.hardwareApplies(to: video)
            guard bitrateMode else { return nil }
            var bitsPerSec = video.bitrateMbps * 1_000_000
            if video.audio != .none && video.audio != .copy {
                bitsPerSec += Double(video.audioBitrate.rawValue) * 1000
            }
            return Int64(bitsPerSec / 8 * duration)
        case .audio:
            guard audio.format.isLossy else { return nil }
            let bitsPerSec = Double(audio.bitrate.rawValue) * 1000
            return Int64(bitsPerSec / 8 * duration)
        case .image:
            return nil
        }
    }
}
