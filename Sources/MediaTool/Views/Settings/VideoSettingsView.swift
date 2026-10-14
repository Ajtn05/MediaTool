import SwiftUI

struct VideoSettingsView: View {
    @EnvironmentObject var app: AppState

    private var hwAvailable: Bool {
        app.video.codec == .h264 || app.video.codec == .hevc
    }
    private var hwActive: Bool { hwAvailable && app.video.useHardware }

    var body: some View {
        Card(title: "Video", systemImage: "film") {
            SettingRow(title: "Codec", info: HelpText.codec(app.video.codec)) {
                UtilityPicker(
                    options: VideoCodec.allCases, selection: $app.video.codec, label: { $0.rawValue }
                )
                .frame(width: 190, alignment: .leading)
                .onChange(of: app.video.codec) { newCodec in
                    if !newCodec.compatibleContainers.contains(app.video.container) {
                        app.video.container = newCodec.compatibleContainers.first ?? .mp4
                    }
                    app.video.crf = newCodec.defaultCRF
                }
            }

            SettingRow(title: "Container", info: HelpText.container) {
                UtilityPicker(
                    options: app.video.codec.compatibleContainers, selection: $app.video.container,
                    label: { $0.rawValue }
                )
                .frame(width: 150, alignment: .leading)
            }

            if hwAvailable {
                SettingRow(title: "Hardware", info: HelpText.hardware) {
                    Toggle("Use VideoToolbox (faster)", isOn: $app.video.useHardware)
                        .font(TypeScale.body)
                }
            }

            if app.video.codec.usesCRF {
                if hwActive {
                    bitrateRow
                } else {
                    SettingRow(title: "Quality by", info: HelpText.qualityMode) {
                        SegmentedControl(
                            options: QualityMode.allCases,
                            selection: Binding(
                                get: { app.video.useBitrate ? .bitrate : .constant },
                                set: { app.video.useBitrate = ($0 == .bitrate) }
                            ),
                            label: { $0.rawValue })
                    }

                    if app.video.useBitrate {
                        bitrateRow
                    } else {
                        SettingRow(title: "Quality", info: HelpText.crf) {
                            HStack(spacing: 10) {
                                Slider(
                                    value: $app.video.crf.snapped(),
                                    in: app.video.codec.crfRange
                                )
                                .frame(minWidth: 90, maxWidth: 180)
                                ValueTag(text: "CRF \(Int(app.video.crf))", width: 62)
                            }
                        }
                    }

                    SettingRow(title: "Speed", info: HelpText.speed) {
                        UtilityPicker(
                            options: EncoderSpeed.allCases, selection: $app.video.speed, label: { $0.label }
                        )
                        .frame(width: 150, alignment: .leading)
                    }
                }
            }

            HairlineDivider()

            SettingRow(title: "Resolution", info: HelpText.resolution) {
                UtilityPicker(
                    options: ResolutionPreset.allCases, selection: $app.video.resolution,
                    label: { $0.rawValue }
                )
                .frame(width: 150, alignment: .leading)
            }
            if app.video.resolution == .custom {
                SettingRow(title: "Size") {
                    HStack(spacing: 6) {
                        IntField(value: $app.video.customWidth)
                        Text("×").foregroundColor(Palette.onSurfaceVariant)
                        IntField(value: $app.video.customHeight)
                    }
                }
            }

            SettingRow(title: "Frame rate", info: HelpText.framerate) {
                UtilityPicker(
                    options: FrameratePreset.allCases, selection: $app.video.framerate, label: { $0.rawValue }
                )
                .frame(width: 150, alignment: .leading)
            }
            if app.video.framerate == .custom {
                SettingRow(title: "FPS") {
                    DoubleField(value: $app.video.customFramerate)
                }
            }
        }

        DesqueezeSection()

        Card(title: "Audio", systemImage: "waveform") {
            SettingRow(title: "Track", info: HelpText.audioTrack) {
                UtilityPicker(
                    options: AudioTrack.allCases, selection: $app.video.audio, label: { $0.rawValue }
                )
                .frame(width: 150, alignment: .leading)
            }
            if app.video.audio != .copy && app.video.audio != .none {
                SettingRow(title: "Bitrate", info: HelpText.audioBitrate) {
                    UtilityPicker(
                        options: AudioBitrate.allCases, selection: $app.video.audioBitrate,
                        label: { $0.label }
                    )
                    .frame(width: 150, alignment: .leading)
                }
            }
        }

        SpeedSection(settings: $app.video.playbackSpeed)

        TrimSection(
            enabled: $app.video.trimEnabled,
            start: $app.video.trimStart,
            end: $app.video.trimEnd)

        TransformSection(
            rotation: $app.video.rotation,
            flipH: $app.video.flipH,
            flipV: $app.video.flipV,
            cropEnabled: $app.video.cropEnabled,
            cropX: $app.video.cropX,
            cropY: $app.video.cropY,
            cropW: $app.video.cropW,
            cropH: $app.video.cropH)
    }

    private var bitrateRow: some View {
        SettingRow(title: "Bitrate", info: HelpText.bitrate) {
            HStack(spacing: 10) {
                Slider(value: $app.video.bitrateMbps.snapped(to: 0.5), in: 0.5...50)
                    .frame(minWidth: 90, maxWidth: 180)
                ValueTag(text: String(format: "%.1f Mbps", app.video.bitrateMbps), width: 74)
            }
        }
    }
}

// MARK: - De-squeeze

/// Restores the true shape of footage that was recorded squeezed — anamorphic adapters, or a
/// camera profile that wrote the wrong aspect ratio. Video-only, so it lives here rather than
/// in SharedSections.
struct DesqueezeSection: View {
    @EnvironmentObject var app: AppState

    private var settings: DesqueezeSettings { app.video.desqueeze }

    /// Frame size of the first staged clip, so the readout can show real numbers.
    private var sourceSize: PixelSize? {
        app.stagedURLs.first.flatMap { app.cachedSize(of: $0) }
    }

    var body: some View {
        Card(title: "De-squeeze", systemImage: "aspectratio") {
            SettingRow(title: "Mode", info: HelpText.desqueeze) {
                SegmentedControl(
                    options: DesqueezeSettings.Mode.allCases,
                    selection: $app.video.desqueeze.mode,
                    label: { $0.rawValue })
            }

            if settings.mode != .none {
                SettingRow(title: "Factor", info: HelpText.desqueezeFactor) {
                    HStack(spacing: 10) {
                        Slider(value: $app.video.desqueeze.factor.snapped(to: 0.01), in: 0.5...2.5)
                            .frame(minWidth: 90, maxWidth: 190)
                        ValueTag(text: String(format: "%.2f×", settings.factor), width: 60)
                    }
                }

                HStack(spacing: 6) {
                    ForEach(DesqueezeSettings.commonFactors, id: \.self) { preset in
                        Button(String(format: "%g×", preset)) {
                            app.video.desqueeze.factor = preset
                        }
                        .buttonStyle(TonalButtonStyle())
                    }
                    Button("1×") { app.video.desqueeze.factor = 1 }
                        .buttonStyle(TonalButtonStyle())
                }
                .padding(.leading, Metrics.labelColumn + 10)

                if let note {
                    Text(note.text)
                        .font(TypeScale.caption)
                        .foregroundColor(note.isWarning ? Palette.error : Palette.onSurfaceVariant)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, Metrics.labelColumn + 10)
                }
            }
        }
    }

    /// Plain-language summary of what the current mode/factor will actually do.
    private var note: (text: String, isWarning: Bool)? {
        guard settings.mode != .none else { return nil }

        if settings.mode == .rescale && settings.isActive && app.video.codec.isCopy {
            return (
                "Rescaling resamples the picture, which \"Copy\" can't do. Pick a codec, or use Tag instead.",
                true
            )
        }
        guard settings.isActive else {
            return ("1.00× leaves the picture as it is.", false)
        }
        guard let size = sourceSize else {
            return settings.mode == .tag
                ? ("Add a clip — tagging needs its frame size to write the ratio.", false)
                : ("Width is multiplied by the factor; height stays as it is.", false)
        }

        // Mirrors the builder: -aspect rounds, the scale filter truncates to an even width.
        let stretched = Double(size.width) * settings.factor
        let width =
            settings.mode == .tag
            ? max(1, Int(stretched.rounded()))
            : max(2, Int(stretched / 2) * 2)
        let shape = String(format: "%.2f:1", Double(width) / Double(size.height))

        switch settings.mode {
        case .tag:
            return (
                "\(size.width)×\(size.height) stays as-is, tagged to display as \(width)×\(size.height) — \(shape).",
                false
            )
        case .rescale:
            return ("\(size.width)×\(size.height) → \(width)×\(size.height) — \(shape).", false)
        case .none:
            return nil
        }
    }
}

/// Two-way choice for how video quality is specified.
enum QualityMode: String, CaseIterable, Identifiable {
    case constant = "Quality"
    case bitrate = "Bitrate"
    var id: String { rawValue }
}

// MARK: - Small numeric fields

struct IntField: View {
    @Binding var value: Int
    var width: CGFloat = 74

    var body: some View {
        TextField("", value: $value, format: .number)
            .font(TypeScale.mono)
            .multilineTextAlignment(.trailing)
            .roundedField()
            .frame(width: width)
    }
}

struct DoubleField: View {
    @Binding var value: Double
    var width: CGFloat = 74

    var body: some View {
        TextField("", value: $value, format: .number)
            .font(TypeScale.mono)
            .multilineTextAlignment(.trailing)
            .roundedField()
            .frame(width: width)
    }
}
