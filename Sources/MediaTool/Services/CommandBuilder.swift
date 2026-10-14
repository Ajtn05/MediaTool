import Foundation

/// Pure translation of settings into argument vectors. No side effects, so the exact same
/// output drives both execution (JobQueue) and the on-screen command preview.
enum CommandBuilder {

    // MARK: Video (ffmpeg)

    /// `sourceSize` is only needed by the "tag" de-squeeze mode, which has to turn the user's
    /// horizontal factor into the *display* ratio ffmpeg's `-aspect` expects. Everything else
    /// builds fine without it.
    static func videoArgs(
        input: URL,
        output: URL,
        settings s: VideoSettings,
        sourceSize: PixelSize? = nil
    ) -> [String] {
        var args: [String] = ["-y"]
        args += trimArgs(enabled: s.trimEnabled, start: s.trimStart, end: s.trimEnd)
        args += ["-i", input.path]

        // Video stream
        if s.codec.isCopy {
            args += ["-c:v", "copy"]
        } else {
            args += ["-c:v", encoderName(for: s)]
            args += qualityArgs(for: s)

            if s.codec == .hevc && (s.container == .mp4 || s.container == .mov) {
                args += ["-tag:v", "hvc1"]
            }

            // Filters require a re-encode, so only apply them when not copying.
            if let vf = videoFilterChain(for: s) {
                args += ["-vf", vf]
            }
        }

        // Metadata-only de-squeeze. Deliberately outside the codec branch above: it's a container
        // tag, not a filter, so it also applies when the video stream is copied.
        args += aspectArgs(for: s, sourceSize: sourceSize)

        if let fps = framerateValue(for: s) {
            args += ["-r", trimmed(fps)]
        }

        // Audio stream
        switch s.audio {
        case .none:
            args += ["-an"]
        case .copy:
            args += ["-c:a", "copy"]
        default:
            if let enc = s.audio.encoder {
                args += ["-c:a", enc, "-b:a", s.audioBitrate.argument]
                // Keep audio in sync with a speed change (only possible when re-encoding).
                if s.playbackSpeed.enabled, s.playbackSpeed.rate != 1 {
                    let chain = atempoChain(s.playbackSpeed.rate)
                    if !chain.isEmpty { args += ["-af", chain.joined(separator: ",")] }
                }
            }
        }

        if s.container == .mp4 || s.container == .mov {
            args += ["-movflags", "+faststart"]
        }

        args.append(output.path)
        return args
    }

    /// Whether hardware (VideoToolbox) encoding applies to the current codec.
    static func hardwareApplies(to s: VideoSettings) -> Bool {
        s.useHardware && (s.codec == .h264 || s.codec == .hevc)
    }

    private static func encoderName(for s: VideoSettings) -> String {
        if hardwareApplies(to: s) {
            return s.codec == .h264 ? "h264_videotoolbox" : "hevc_videotoolbox"
        }
        return s.codec.encoder ?? "libx264"
    }

    private static func qualityArgs(for s: VideoSettings) -> [String] {
        // VideoToolbox is bitrate-driven — it ignores CRF.
        if hardwareApplies(to: s) {
            return ["-b:v", "\(trimmed(s.bitrateMbps))M"]
        }
        if s.useBitrate {
            return ["-b:v", "\(trimmed(s.bitrateMbps))M"]
        }
        let crf = String(Int(s.crf.rounded()))
        switch s.codec {
        case .h264, .hevc:
            return ["-crf", crf, "-preset", s.speed.rawValue]
        case .vp9:
            return ["-crf", crf, "-b:v", "0", "-cpu-used", String(vp9CPUUsed(s.speed)), "-row-mt", "1"]
        case .av1:
            return ["-crf", crf, "-preset", String(svtPreset(s.speed))]
        case .copy:
            return []
        }
    }

    /// Assembles crop → de-squeeze → scale → rotate → flip into a single -vf chain.
    private static func videoFilterChain(for s: VideoSettings) -> String? {
        var parts: [String] = []

        if s.cropEnabled {
            parts.append("crop=\(max(2, s.cropW)):\(max(2, s.cropH)):\(max(0, s.cropX)):\(max(0, s.cropY))")
        }
        if let desqueeze = desqueezeFilter(for: s) {
            parts.append(desqueeze)
        }
        if let scale = scaleFilter(for: s) {
            parts.append(scale)
        }
        switch s.rotation {
        case .none: break
        case .r90: parts.append("transpose=1")
        case .r270: parts.append("transpose=2")
        case .r180: parts.append("transpose=1,transpose=1")
        }
        if s.flipH { parts.append("hflip") }
        if s.flipV { parts.append("vflip") }
        if s.playbackSpeed.enabled, s.playbackSpeed.rate != 1 {
            // Faster playback = smaller presentation timestamps.
            parts.append("setpts=\(trimmed(1 / s.playbackSpeed.rate))*PTS")
        }

        return parts.isEmpty ? nil : parts.joined(separator: ",")
    }

    /// `atempo` only accepts 0.5…2.0, so larger changes are chained.
    /// e.g. 4× → "atempo=2.0,atempo=2.0"; 0.25× → "atempo=0.5,atempo=0.5".
    static func atempoChain(_ rate: Double) -> [String] {
        guard rate > 0, rate != 1 else { return [] }
        var remaining = rate
        var stages: [String] = []
        while remaining > 2.0 && stages.count < 8 {
            stages.append("atempo=2.0")
            remaining /= 2.0
        }
        while remaining < 0.5 && stages.count < 8 {
            stages.append("atempo=0.5")
            remaining /= 0.5
        }
        stages.append("atempo=\(trimmed(remaining))")
        return stages
    }

    /// Stretches width by the de-squeeze factor while holding height, so the frame ends up its
    /// true shape. The width is written as an expression on `iw`, which keeps the builder free of
    /// any need to know the source size; `trunc(…/2)*2` keeps it even for the encoders that
    /// insist on it. `setsar=1` then declares the result square-pixel, so a source that already
    /// carried an aspect tag doesn't get squeezed a second time on playback.
    private static func desqueezeFilter(for s: VideoSettings) -> String? {
        guard s.desqueeze.mode == .rescale, s.desqueeze.isActive else { return nil }
        return "scale=trunc(iw*\(trimmed(s.desqueeze.factor))/2)*2:ih,setsar=1"
    }

    /// De-squeeze as a pure container tag. `-aspect` wants a *display* ratio, so the horizontal
    /// factor is folded into the source's own width; without a probed size there's nothing to
    /// fold it into and the tag is skipped.
    private static func aspectArgs(for s: VideoSettings, sourceSize: PixelSize?) -> [String] {
        guard s.desqueeze.mode == .tag, s.desqueeze.isActive,
            let size = sourceSize, size.width > 0, size.height > 0
        else { return [] }
        let width = max(1, Int((Double(size.width) * s.desqueeze.factor).rounded()))
        return ["-aspect", "\(width):\(size.height)"]
    }

    private static func scaleFilter(for s: VideoSettings) -> String? {
        switch s.resolution {
        case .original:
            return nil
        case .custom:
            return "scale=\(max(2, s.customWidth)):\(max(2, s.customHeight))"
        default:
            guard let h = s.resolution.height else { return nil }
            return "scale=-2:\(h)"
        }
    }

    private static func framerateValue(for s: VideoSettings) -> Double? {
        switch s.framerate {
        case .original: return nil
        case .custom: return s.customFramerate
        default: return s.framerate.value
        }
    }

    private static func vp9CPUUsed(_ speed: EncoderSpeed) -> Int {
        switch speed {
        case .veryslow, .slower, .slow: return 1
        case .medium: return 2
        case .fast, .faster: return 3
        case .veryfast, .superfast: return 4
        case .ultrafast: return 5
        }
    }

    private static func svtPreset(_ speed: EncoderSpeed) -> Int {
        switch speed {
        case .veryslow: return 2
        case .slower: return 3
        case .slow: return 4
        case .medium: return 6
        case .fast: return 7
        case .faster: return 8
        case .veryfast: return 9
        case .superfast: return 10
        case .ultrafast: return 12
        }
    }

    // MARK: Audio (ffmpeg)

    static func audioArgs(input: URL, output: URL, settings s: AudioSettings) -> [String] {
        var args: [String] = ["-y"]
        args += trimArgs(enabled: s.trimEnabled, start: s.trimStart, end: s.trimEnd)
        args += ["-i", input.path]

        args += ["-vn", "-c:a", s.format.encoder]
        if s.format.isLossy {
            args += ["-b:a", s.bitrate.argument]
        }

        // Audio filter chain.
        var af: [String] = []
        if s.playbackSpeed.enabled, s.playbackSpeed.rate != 1 { af += atempoChain(s.playbackSpeed.rate) }
        if s.normalize { af.append("loudnorm") }
        if s.gainEnabled && s.gainDB != 0 { af.append("volume=\(trimmed(s.gainDB))dB") }
        if !af.isEmpty { args += ["-af", af.joined(separator: ",")] }

        if s.sampleRate != .original { args += ["-ar", String(s.sampleRate.rawValue)] }
        if s.channels != .original { args += ["-ac", String(s.channels.rawValue)] }

        args.append(output.path)
        return args
    }

    // MARK: Image (ImageMagick)

    /// A watermark resolved to concrete pixels. Computed by the caller (which knows the source
    /// dimensions) so the builder itself stays pure.
    struct WatermarkPlacement: Equatable {
        let logo: URL
        let widthPx: Int
        let offsetX: Int
        let offsetY: Int
        let opacity: Double  // 0…1
    }

    /// Predicts the finished pixel size for a set of image settings, so a watermark can be sized
    /// and positioned relative to the *output* rather than the source. Mirrors the op order below.
    static func finalDimensions(source: PixelSize, settings s: ImageSettings) -> PixelSize {
        var w = Double(source.width)
        var h = Double(source.height)

        if s.cropEnabled {
            w = Double(min(s.cropW, source.width))
            h = Double(min(s.cropH, source.height))
        }
        if s.rotation == .r90 || s.rotation == .r270 {
            swap(&w, &h)
        }

        switch s.resize {
        case .none:
            break
        case .maxDimension:
            let m = Double(s.maxDimension)
            if w > m || h > m {  // "WxH>" only ever shrinks
                let k = min(m / w, m / h)
                w = (w * k).rounded()
                h = (h * k).rounded()
            }
        case .percent:
            let k = s.percent / 100
            w = (w * k).rounded()
            h = (h * k).rounded()
        case .factor:
            let k = s.scaleFactor
            w = (w * k).rounded()
            h = (h * k).rounded()
        case .exact:
            if s.keepAspect {
                let k = min(Double(s.exactWidth) / w, Double(s.exactHeight) / h)
                w = (w * k).rounded()
                h = (h * k).rounded()
            } else {
                w = Double(s.exactWidth)
                h = Double(s.exactHeight)
            }
        }

        switch s.border.mode {
        case .none:
            break
        case .border:
            w += Double(s.border.thickness * 2)
            h += Double(s.border.thickness * 2)
        case .padToCanvas:
            w = Double(s.border.canvasWidth)
            h = Double(s.border.canvasHeight)
        }

        return PixelSize(width: max(1, Int(w)), height: max(1, Int(h)))
    }

    /// Composites the logo last, so it lands on the finished canvas and is never cropped,
    /// rotated, or rescaled by the operations above it.
    private static func watermarkArgs(_ wm: WatermarkPlacement?) -> [String] {
        guard let wm else { return [] }
        return [
            "(", wm.logo.path,
            "-resize", "\(wm.widthPx)x",
            "-alpha", "set",
            "-channel", "A", "-evaluate", "multiply", trimmed(wm.opacity), "+channel",
            ")",
            "-gravity", "northwest",
            "-geometry", "+\(wm.offsetX)+\(wm.offsetY)",
            "-composite",
        ]
    }

    static func imageArgs(
        input: URL,
        output: URL,
        settings s: ImageSettings,
        watermark: WatermarkPlacement? = nil
    ) -> [String] {
        var args: [String] = [input.path, "-auto-orient"]

        if s.cropEnabled {
            args += ["-crop", "\(s.cropW)x\(s.cropH)+\(s.cropX)+\(s.cropY)", "+repage"]
        }
        if s.rotation != .none {
            args += ["-rotate", String(s.rotation.rawValue)]
        }
        if s.flipV { args.append("-flip") }
        if s.flipH { args.append("-flop") }

        args += resizeArgs(for: s)
        args += colorArgs(for: s)
        args += borderArgs(for: s)
        args += watermarkArgs(watermark)

        if s.stripMetadata { args.append("-strip") }
        if s.format.usesQuality && s.format != .pdf {
            args += ["-quality", String(Int(s.quality.rounded()))]
        }

        args.append(output.path)
        return args
    }

    private static func borderArgs(for s: ImageSettings) -> [String] {
        switch s.border.mode {
        case .none:
            return []
        case .border:
            let t = max(0, s.border.thickness)
            return ["-bordercolor", s.border.colorHex, "-border", "\(t)x\(t)"]
        case .padToCanvas:
            // Center the image on a fixed canvas without scaling it up.
            return [
                "-background", s.border.colorHex,
                "-gravity", "center",
                "-extent", "\(s.border.canvasWidth)x\(s.border.canvasHeight)",
            ]
        }
    }

    // MARK: Extract frames (ffmpeg, 1 input → many files)

    /// `output` is a pattern like `.../clip-frames/frame_%04d.png`.
    static func extractFramesArgs(input: URL, outputPattern: URL, settings s: FrameExtractSettings)
        -> [String]
    {
        var args: [String] = ["-y"]

        // For a single frame, seeking before -i is much faster and is exact enough here.
        if s.mode == .singleFrame, let ts = sanitizedTime(s.timestamp) {
            args += ["-ss", ts]
        }
        args += ["-i", input.path]

        switch s.mode {
        case .everySeconds:
            args += ["-vf", "fps=1/\(trimmed(max(0.01, s.seconds)))"]
        case .everyNthFrame:
            let n = max(1, s.nthFrame)
            // -fps_mode replaces the deprecated -vsync (removed warning on ffmpeg 7+).
            args += ["-vf", "select=not(mod(n\\,\(n)))", "-fps_mode", "vfr"]
        case .singleFrame:
            args += ["-frames:v", "1"]
        }

        if s.format.usesQuality {
            args += ["-q:v", String(Int((100 - s.quality) / 100 * 30) + 1)]
        }
        args.append(outputPattern.path)
        return args
    }

    // MARK: Join (ffmpeg, many inputs → 1 output)

    /// Uses the concat *filter* rather than the demuxer so no temp list file is needed and
    /// inputs with differing codecs/resolutions still work. Requires every input to have an
    /// audio stream when `includeAudio` is on.
    static func joinArgs(inputs: [URL], output: URL, settings s: JoinSettings) -> [String] {
        var args: [String] = ["-y"]
        for input in inputs { args += ["-i", input.path] }

        let n = inputs.count
        let streams = (0..<n).map { i in
            s.includeAudio ? "[\(i):v:0][\(i):a:0]" : "[\(i):v:0]"
        }.joined()
        let filter =
            s.includeAudio
            ? "\(streams)concat=n=\(n):v=1:a=1[outv][outa]"
            : "\(streams)concat=n=\(n):v=1:a=0[outv]"

        args += ["-filter_complex", filter, "-map", "[outv]"]
        if s.includeAudio { args += ["-map", "[outa]"] }

        args += ["-c:v", s.codec.encoder ?? "libx264"]
        if s.codec != .copy {
            args += ["-crf", String(Int(s.crf.rounded()))]
            if s.codec == .h264 || s.codec == .hevc {
                args += ["-preset", s.speed.rawValue]
            }
        }
        if s.includeAudio {
            args += ["-c:a", "aac", "-b:a", s.audioBitrate.argument]
        }
        if s.container == .mp4 || s.container == .mov {
            args += ["-movflags", "+faststart"]
        }
        args.append(output.path)
        return args
    }

    // MARK: Contact sheet (ImageMagick montage, many inputs → 1 output)

    /// `fontPath` must be a real font file — `montage` draws filename labels by default and
    /// aborts with "unable to read font" when none is configured, so we always supply one and
    /// pass an explicit empty label when labels are turned off.
    static func contactSheetArgs(
        inputs: [URL],
        output: URL,
        settings s: ContactSheetSettings,
        fontPath: String?
    ) -> [String] {
        var args: [String] = ["montage"]
        args += inputs.map { $0.path }
        args += [
            "-tile", "\(max(1, s.columns))x",
            "-geometry", "\(s.cellSize)x\(s.cellSize)+\(s.padding)+\(s.padding)",
            "-background", s.backgroundHex,
        ]

        if let fontPath { args += ["-font", fontPath] }

        if s.showLabels && fontPath != nil {
            args += ["-label", "%f", "-fill", "#111111", "-pointsize", "13"]
        } else {
            args += ["-label", ""]
        }

        if s.format.usesQuality {
            args += ["-quality", String(Int(s.quality.rounded()))]
        }
        args.append(output.path)
        return args
    }

    // MARK: Multi-size export (ImageMagick, one command per size)

    static func multiSizeArgs(input: URL, output: URL, size: Int, settings s: MultiSizeSettings) -> [String] {
        var args: [String] = [input.path, "-auto-orient", "-resize", "\(size)x\(size)"]
        if s.format.usesQuality {
            args += ["-quality", String(Int(s.quality.rounded()))]
        }
        args.append(output.path)
        return args
    }

    /// Combines several images into one multi-page PDF (single ImageMagick invocation).
    static func imagePDFArgs(inputs: [URL], output: URL, settings s: ImageSettings) -> [String] {
        var args: [String] = inputs.map { $0.path }
        args.append("-auto-orient")
        args += resizeArgs(for: s)
        args += colorArgs(for: s)
        if s.stripMetadata { args.append("-strip") }
        args.append(output.path)
        return args
    }

    private static func resizeArgs(for s: ImageSettings) -> [String] {
        switch s.resize {
        case .none:
            return []
        case .maxDimension:
            return ["-resize", "\(s.maxDimension)x\(s.maxDimension)>"]
        case .percent:
            return ["-resize", "\(trimmed(s.percent))%"]
        case .factor:
            // Expressed as a percentage so one code path handles every image, whatever its size —
            // rounded to two decimals to keep binary-float noise (0.7×3 = 209.99999…%) out of the
            // command preview.
            let percent = (s.scaleFactor * 10_000).rounded() / 100
            return ["-resize", "\(trimmed(percent))%"]
        case .exact:
            let spec = "\(s.exactWidth)x\(s.exactHeight)"
            return ["-resize", s.keepAspect ? spec : spec + "!"]
        }
    }

    private static func colorArgs(for s: ImageSettings) -> [String] {
        if s.grayscale {
            return ["-colorspace", "Gray"]
        }
        var args: [String] = []
        if s.brightness != 0 || s.contrast != 0 {
            args += ["-brightness-contrast", "\(Int(s.brightness))x\(Int(s.contrast))"]
        }
        if s.saturation != 0 {
            // -modulate brightness,saturation,hue — 100 = unchanged.
            args += ["-modulate", "100,\(Int(100 + s.saturation)),100"]
        }
        return args
    }

    // MARK: Helpers

    /// Trim as **input-side** options, i.e. emitted before `-i`.
    ///
    /// This matters when a speed change is also active: placed after `-i`, `-ss`/`-to` describe the
    /// *output* timeline, so "trim 0–3s at 1.5×" yields 3s of sped-up material instead of trimming
    /// 3s of source down to 2s. Input-side seeking is frame-accurate by default in modern ffmpeg,
    /// so there's no downside for the plain-trim case.
    private static func trimArgs(enabled: Bool, start: String, end: String) -> [String] {
        guard enabled else { return [] }
        var args: [String] = []
        if let start = sanitizedTime(start) { args += ["-ss", start] }
        if let end = sanitizedTime(end) { args += ["-to", end] }
        return args
    }

    /// Returns a trimmed timestamp if it looks like a time value, else nil.
    private static func sanitizedTime(_ raw: String) -> String? {
        let t = raw.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, t.contains(where: { $0.isNumber }) else { return nil }
        return t
    }

    /// Formats a double without a trailing ".0".
    private static func trimmed(_ value: Double) -> String {
        if value == value.rounded() {
            return String(Int(value))
        }
        return String(value)
    }
}
