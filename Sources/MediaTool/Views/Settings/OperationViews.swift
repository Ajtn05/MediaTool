import SwiftUI

// MARK: - Extract frames

struct FrameExtractView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        Card(title: "Extract Frames", systemImage: "photo.stack") {
            SettingRow(title: "Mode", info: HelpText.frameMode) {
                UtilityPicker(
                    options: FrameExtractSettings.Mode.allCases, selection: $app.frames.mode,
                    label: { $0.rawValue }
                )
                .frame(width: 190, alignment: .leading)
            }

            switch app.frames.mode {
            case .everySeconds:
                SettingRow(title: "Interval") {
                    HStack(spacing: 10) {
                        Slider(value: $app.frames.seconds.snapped(to: 0.5), in: 0.5...30)
                            .frame(minWidth: 90, maxWidth: 170)
                        ValueTag(text: String(format: "%.1f s", app.frames.seconds), width: 60)
                    }
                }
            case .everyNthFrame:
                SettingRow(title: "Every") {
                    HStack(spacing: 6) {
                        IntField(value: $app.frames.nthFrame)
                        Text("frames").font(TypeScale.caption).foregroundColor(Palette.onSurfaceVariant)
                    }
                }
            case .singleFrame:
                SettingRow(title: "At time") {
                    TimeField(text: $app.frames.timestamp)
                }
            }

            SettingRow(title: "Format", info: HelpText.imageFormat(app.frames.format)) {
                UtilityPicker(
                    options: [ImageFormat.png, .jpg, .webp, .tiff], selection: $app.frames.format,
                    label: { $0.rawValue }
                )
                .frame(width: 150, alignment: .leading)
            }

            if app.frames.format.usesQuality {
                SettingRow(title: "Quality") {
                    HStack(spacing: 10) {
                        Slider(value: $app.frames.quality.snapped(), in: 1...100)
                            .frame(minWidth: 90, maxWidth: 170)
                        ValueTag(text: "\(Int(app.frames.quality))", width: 40)
                    }
                }
            }

            Text("Stills are written into a “<name>-frames” folder next to the video.")
                .font(TypeScale.caption)
                .foregroundColor(Palette.onSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Join

struct JoinView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        Card(title: "Join Clips", systemImage: "arrow.trianglehead.merge") {
            Text("All added clips are concatenated in list order into one file.")
                .font(TypeScale.caption)
                .foregroundColor(Palette.onSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)

            SettingRow(title: "Container", info: HelpText.container) {
                UtilityPicker(
                    options: app.join.codec.compatibleContainers, selection: $app.join.container,
                    label: { $0.rawValue }
                )
                .frame(width: 150, alignment: .leading)
            }

            SettingRow(title: "Codec", info: HelpText.codec(app.join.codec)) {
                UtilityPicker(
                    options: [VideoCodec.h264, .hevc, .vp9, .av1], selection: $app.join.codec,
                    label: { $0.rawValue }
                )
                .frame(width: 170, alignment: .leading)
                .onChange(of: app.join.codec) { newCodec in
                    if !newCodec.compatibleContainers.contains(app.join.container) {
                        app.join.container = newCodec.compatibleContainers.first ?? .mp4
                    }
                }
            }

            SettingRow(title: "Quality", info: HelpText.crf) {
                HStack(spacing: 10) {
                    Slider(value: $app.join.crf.snapped(), in: app.join.codec.crfRange)
                        .frame(minWidth: 90, maxWidth: 170)
                    ValueTag(text: "CRF \(Int(app.join.crf))", width: 60)
                }
            }

            SettingRow(title: "Audio", info: HelpText.joinAudio) {
                Toggle("Include audio track", isOn: $app.join.includeAudio)
                    .font(TypeScale.body)
            }

            if app.join.includeAudio {
                SettingRow(title: "Bitrate", info: HelpText.audioBitrate) {
                    UtilityPicker(
                        options: AudioBitrate.allCases, selection: $app.join.audioBitrate, label: { $0.label }
                    )
                    .frame(width: 150, alignment: .leading)
                }
            }
        }
    }
}

// MARK: - Contact sheet

struct ContactSheetView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        Card(title: "Contact Sheet", systemImage: "square.grid.3x3") {
            Text("All added images are tiled into one sheet, in list order.")
                .font(TypeScale.caption)
                .foregroundColor(Palette.onSurfaceVariant)

            SettingRow(title: "Columns", info: HelpText.sheetColumns) {
                HStack(spacing: 10) {
                    Slider(
                        value: Binding(
                            get: { Double(app.sheet.columns) },
                            set: { app.sheet.columns = Int($0.rounded()) }
                        ), in: 1...10
                    )
                    .frame(minWidth: 90, maxWidth: 170)
                    ValueTag(text: "\(app.sheet.columns)", width: 30)
                }
            }

            SettingRow(title: "Cell size", info: HelpText.sheetCell) {
                HStack(spacing: 6) {
                    IntField(value: $app.sheet.cellSize)
                    Text("px  gap").font(TypeScale.caption).foregroundColor(Palette.onSurfaceVariant)
                    IntField(value: $app.sheet.padding)
                }
            }

            SettingRow(title: "Labels", info: HelpText.sheetLabels) {
                let hasFont = ToolLocator.labelFontPath != nil
                Toggle(
                    hasFont ? "Show filenames" : "Show filenames (no font found)",
                    isOn: $app.sheet.showLabels
                )
                .font(TypeScale.body)
                .disabled(!hasFont)
            }

            SettingRow(title: "Background") {
                HexColorField(hex: $app.sheet.backgroundHex)
            }

            SettingRow(title: "Format", info: HelpText.imageFormat(app.sheet.format)) {
                UtilityPicker(
                    options: [ImageFormat.jpg, .png, .webp], selection: $app.sheet.format,
                    label: { $0.rawValue }
                )
                .frame(width: 150, alignment: .leading)
            }
        }
    }
}

// MARK: - Multi-size export

struct MultiSizeView: View {
    @EnvironmentObject var app: AppState

    private let columns = [GridItem(.adaptive(minimum: 74), spacing: 8)]

    var body: some View {
        Card(title: "Export Sizes", systemImage: "square.resize") {
            Text("Each selected size becomes its own file, e.g. icon-256.png.")
                .font(TypeScale.caption)
                .foregroundColor(Palette.onSurfaceVariant)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(MultiSizeSettings.commonSizes, id: \.self) { size in
                    let selected = app.multiSize.sizes.contains(size)
                    Button {
                        if selected {
                            app.multiSize.sizes.removeAll { $0 == size }
                        } else {
                            app.multiSize.sizes.append(size)
                        }
                    } label: {
                        Text("\(size)")
                            .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                            .foregroundColor(
                                selected ? Palette.onSecondaryContainer : Palette.onSurfaceVariant
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(selected ? Palette.secondaryContainer : Color.clear)
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(
                                        selected ? Color.clear : Palette.outline,
                                        lineWidth: Metrics.hairline)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.trailing, 4)

            HStack(spacing: 6) {
                InfoButton(text: HelpText.multiSizes)
                Text("\(app.multiSize.sizes.count) selected")
                    .font(TypeScale.body)
                    .foregroundColor(Palette.onSurfaceVariant)
                Spacer()
                Button("Clear") { app.multiSize.sizes = [] }
                    .buttonStyle(TextButtonStyle())
            }

            SettingRow(title: "Format", info: HelpText.imageFormat(app.multiSize.format)) {
                UtilityPicker(
                    options: [ImageFormat.png, .jpg, .webp], selection: $app.multiSize.format,
                    label: { $0.rawValue }
                )
                .frame(width: 150, alignment: .leading)
            }
        }
    }
}

// MARK: - Hex color field

/// A color well plus its hex value, since the tools take hex strings.
struct HexColorField: View {
    @Binding var hex: String

    var body: some View {
        HStack(spacing: 8) {
            ColorPicker(
                "",
                selection: Binding(
                    get: { Color(hexString: hex) },
                    set: { hex = $0.hexString }
                ), supportsOpacity: false
            )
            .labelsHidden()

            TextField("#FFFFFF", text: $hex)
                .font(TypeScale.monoSmall)
                .roundedField()
                .frame(width: 88)
        }
    }
}

extension Color {
    /// Parses "#RRGGBB" (tolerating a missing #); falls back to white.
    init(hexString: String) {
        let cleaned = hexString.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0xFFFFFF
        Scanner(string: cleaned).scanHexInt64(&value)
        self.init(hex: UInt32(value & 0xFFFFFF))
    }
}
