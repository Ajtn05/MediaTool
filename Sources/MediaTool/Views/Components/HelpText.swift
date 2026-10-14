import Foundation

/// Centralized help copy for every setting. Kept in one place so descriptions are easy to
/// review and edit. Referenced by the ⓘ info buttons in the settings views.
enum HelpText {

    // MARK: Video

    static let container = """
        The output file wrapper (extension). MP4 is the most compatible; MKV holds almost anything; \
        WebM is for web (VP9/AV1 + Opus); MOV is Apple-friendly.
        """

    static func codec(_ codec: VideoCodec) -> String {
        switch codec {
        case .h264:
            return
                "H.264 — the universal standard. Plays everywhere; larger files than newer codecs. Best default."
        case .hevc:
            return
                "H.265/HEVC — ~50% smaller than H.264 at the same quality, but slower to encode and less universally supported."
        case .vp9:
            return "VP9 — Google's royalty-free codec for the web (WebM). Good compression; slow to encode."
        case .av1:
            return "AV1 — newest royalty-free codec, best compression of all here, but the slowest to encode."
        case .copy:
            return
                "Copy — remux the existing video stream without re-encoding. Instant and lossless, but ignores quality/resolution/filters."
        }
    }

    static let hardware = """
        Encode using your Mac's built-in hardware (Apple VideoToolbox). Dramatically faster and cooler, \
        at a modest quality cost versus software x264/x265. Uses a target bitrate. H.264/HEVC only.
        """

    static let qualityMode = """
        Constant quality (CRF) targets a look and lets the file size vary — best for general use. \
        Target bitrate aims for a specific data rate (and thus size) — useful for upload limits.
        """

    static let crf = """
        Constant Rate Factor. Lower = higher quality and bigger files. Typical: H.264 ≈ 18–24, \
        H.265 ≈ 24–30. 23 is a good default.
        """

    static let bitrate =
        "Target video data rate in megabits per second. Higher = better quality and larger files."

    static let speed = """
        Encoder effort. Slower presets compress better (smaller file at the same quality) but take longer. \
        'medium' is a balanced default.
        """

    static let resolution =
        "Scale the video to a standard height (keeping aspect ratio), or set a custom size."

    static let framerate =
        "Frames per second. Lowering it (e.g. 60 → 30) reduces file size; 'Original' keeps the source rate."

    static let desqueeze = """
        Fixes footage that plays back squeezed — shot through an anamorphic adapter, or recorded with \
        a profile whose aspect ratio the player ignores. Tag only rewrites the file's aspect ratio: \
        instant, lossless, and it works with the "Copy" codec, but it relies on the editor honouring \
        pixel aspect ratio (Premiere, Resolve and Final Cut all do). Rescale really resamples the \
        frames, so the file is correct everywhere — at the cost of a re-encode.
        """

    static let desqueezeFactor = """
        How much to stretch the picture horizontally. 1.33× is the usual anamorphic adapter; 1.5×, \
        1.8× and 2× cover the rest. Below 1× narrows a frame that's too wide instead. Height is never \
        changed.
        """

    static let audioTrack = """
        How to handle audio. AAC is the safe default; Opus is efficient for WebM; MP3 is universal; \
        Copy keeps the original stream; None removes audio entirely.
        """

    static let audioBitrate =
        "Audio data rate. 192 kbps is transparent for most listeners; 256–320 for music."

    // MARK: Trim / transform (shared)

    static let trim = """
        Convert only a section of the file. Use HH:MM:SS (e.g. 00:01:30). Start is where output begins; \
        End is where it stops.
        """

    static let rotation = "Rotate the picture clockwise by the chosen angle."
    static let flip = "Mirror the image horizontally and/or vertically."
    static let crop = """
        Keep only a rectangular region. Width×Height is the size to keep; X/Y is the top-left corner offset \
        in pixels from the original's top-left.
        """

    // MARK: Audio

    static let audioFormat = """
        Output audio format. MP3/M4A/Opus are compressed (smaller); WAV/FLAC are lossless (larger, \
        perfect quality).
        """

    static let normalize = """
        Even out loudness to a broadcast standard (EBU R128) using ffmpeg's loudnorm. Great for podcasts \
        and mixed-source playlists so nothing is too quiet or too loud.
        """

    static let gain =
        "Manually boost or cut volume by a fixed amount in decibels. +6 dB ≈ twice as loud; negative values reduce."

    static let sampleRate =
        "Samples per second. 44.1 kHz is CD quality; 48 kHz is standard for video. 'Original' keeps the source."

    static let channels =
        "Mono mixes to a single channel (smaller); Stereo keeps two. 'Original' leaves it unchanged."

    // MARK: Image

    static func imageFormat(_ format: ImageFormat) -> String {
        switch format {
        case .png: return "PNG — lossless with transparency. Best for graphics, screenshots, and logos."
        case .jpg: return "JPG — lossy, small, universal. Best for photos without transparency."
        case .webp:
            return "WebP — modern format, smaller than JPG/PNG at similar quality, supports transparency."
        case .avif:
            return "AVIF — newest format, excellent compression, but slower and less widely supported."
        case .heic:
            return
                "HEIC — Apple's efficient photo format. Great compression; limited outside Apple ecosystems."
        case .tiff: return "TIFF — lossless, high-fidelity, large. Common in print/archival workflows."
        case .gif: return "GIF — 256 colors, supports simple animation. Best for tiny graphics, not photos."
        case .bmp: return "BMP — uncompressed bitmap. Very large; rarely needed."
        case .pdf: return "PDF — combines ALL added images into one multi-page document, in the order listed."
        }
    }

    static let imageQuality =
        "Compression quality for lossy formats. Higher = better looking and larger. 80–85 is a good balance."

    static let imageResize = """
        Fit within: shrink so neither side exceeds a limit (never enlarges). Percent: scale by a ratio. \
        Factor: multiply every image by the same number (0.5× = half size). \
        Exact: force a specific size (optionally ignoring aspect ratio).
        """

    static let imageScaleFactor = """
        Multiplies each image's own width and height — 0.5× is half size, 2× is double. Because it's \
        relative to each file, a batch of mixed resolutions all shrink by the same amount and keep \
        their proportions, instead of being forced to one common size.
        """

    static let brightnessContrast =
        "Adjust overall lightness and contrast. 0 = no change; positive brightens/adds contrast."
    static let saturation = "Color intensity. 0 = unchanged; positive is more vivid, negative is muted."
    static let grayscale = "Convert the image to shades of gray."
    static let stripMetadata = """
        Remove embedded metadata (EXIF, GPS location, camera info, color profiles) on export. \
        Improves privacy and shrinks the file slightly.
        """

    // MARK: Speed

    static let speedRate = """
        Playback rate. 2× is twice as fast (and half the length); 0.5× is slow motion. Audio is \
        pitch-corrected automatically. Note: this needs a re-encode, so it can't be combined with \
        "Copy" audio.
        """

    // MARK: Operations

    static let videoOperation = """
        Convert re-encodes each file. Frames pulls still images out of a video. Join stitches every \
        added clip into one file.
        """

    static let imageOperation = """
        Convert processes each image. Sheet tiles them into one contact sheet. Sizes exports one image \
        at many resolutions at once.
        """

    static let frameMode = """
        Every N seconds grabs a still on a time interval. Every Nth frame counts actual frames. \
        Single frame grabs exactly one image at a timestamp.
        """

    static let joinAudio = """
        Include the audio track when joining. Turn this OFF if any clip has no audio — otherwise the \
        join fails, because every input must supply an audio stream.
        """

    static let sheetColumns = "How many images per row. Rows are added as needed."
    static let sheetCell = "Maximum size of each thumbnail cell, and the gap between cells."
    static let sheetLabels = "Print each image's filename beneath its thumbnail."

    static let multiSizes = """
        Every selected size is exported as its own file, named like icon-256.png. Handy for app icons, \
        favicons, and @1x/@2x/@3x assets.
        """

    static let borderMode = """
        Border adds a solid frame around the image, growing it. Pad to canvas centers the image on a \
        fixed-size background without scaling it — good for making square social posts.
        """

    // MARK: Watermark

    static let watermarkLogo = """
        A single logo image composited onto every photo. PNG with transparency gives the cleanest \
        result; the logo's own aspect ratio is preserved.
        """

    static let watermarkScale = """
        Logo width as a percentage of the finished image's width. Because it's relative, the logo \
        keeps the same visual size across photos of different resolutions.
        """

    static let watermarkOpacity =
        "How solid the logo is. Around 70–90% reads clearly without dominating the photo."

    static let watermarkPosition = """
        Nine quick anchors — corners, edges, centre. For anything in between, drag the logo directly \
        on the preview. Position is stored relative to the image, so it lands consistently on every \
        photo in a batch.
        """

    // MARK: Output

    static let destination =
        "Where converted files are written — next to each source, or a folder you choose."
    static let suffix =
        "Added to each output filename so originals are never overwritten (e.g. photo → photo-converted.webp)."

    static let naming = """
        Suffix keeps each source filename and appends your text (photo → photo-converted.webp). \
        Rename replaces the name entirely (photo → holiday.webp); when converting several files at \
        once they're numbered automatically (holiday-1, holiday-2, …).
        """
    static let appearance = "Light and dark themes. System follows your macOS appearance setting."

    static let accentColor = """
        The highlight color used for active tabs, buttons, and progress. Modern and Classic remember \
        separate accent choices. Classic defaults to lime.
        """
}
