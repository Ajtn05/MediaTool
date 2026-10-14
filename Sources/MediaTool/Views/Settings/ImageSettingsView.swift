import SwiftUI

struct ImageSettingsView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        ImagePreviewView()

        Card(title: "Image Output", systemImage: "photo") {
            SettingRow(title: "Format", info: HelpText.imageFormat(app.image.format)) {
                UtilityPicker(
                    options: ImageFormat.allCases, selection: $app.image.format, label: { $0.rawValue }
                )
                .frame(width: 160, alignment: .leading)
            }

            if app.image.format.usesQuality && app.image.format != .pdf {
                SettingRow(title: "Quality", info: HelpText.imageQuality) {
                    HStack(spacing: 10) {
                        Slider(value: $app.image.quality.snapped(), in: 1...100)
                            .frame(minWidth: 90, maxWidth: 180)
                        ValueTag(text: "\(Int(app.image.quality))", width: 40)
                    }
                }
            }

            if app.image.format == .pdf {
                Text("All added images are combined into one multi-page PDF.")
                    .font(TypeScale.caption)
                    .foregroundColor(Palette.onSurfaceVariant)
            }

            HairlineDivider()

            SettingRow(title: "Resize", info: HelpText.imageResize) {
                UtilityPicker(
                    options: ImageResizeMode.allCases, selection: $app.image.resize, label: { $0.rawValue }
                )
                .frame(width: 190, alignment: .leading)
            }

            switch app.image.resize {
            case .none:
                EmptyView()
            case .maxDimension:
                SettingRow(title: "Max side") {
                    HStack(spacing: 6) {
                        IntField(value: $app.image.maxDimension)
                        Text("px").font(TypeScale.caption).foregroundColor(Palette.onSurfaceVariant)
                    }
                }
            case .percent:
                SettingRow(title: "Scale") {
                    HStack(spacing: 10) {
                        Slider(value: $app.image.percent.snapped(), in: 1...400)
                            .frame(minWidth: 90, maxWidth: 180)
                        ValueTag(text: "\(Int(app.image.percent))%", width: 46)
                    }
                }
            case .factor:
                ScaleFactorControls()
            case .exact:
                SettingRow(title: "Size") {
                    HStack(spacing: 6) {
                        IntField(value: $app.image.exactWidth)
                        Text("×").foregroundColor(Palette.onSurfaceVariant)
                        IntField(value: $app.image.exactHeight)
                    }
                }
                SettingRow(title: "") {
                    Toggle("Keep aspect ratio", isOn: $app.image.keepAspect)
                        .font(TypeScale.body)
                }
            }
        }

        Card(title: "Adjustments", systemImage: "wand.and.rays") {
            SettingRow(title: "Grayscale", info: HelpText.grayscale) {
                Toggle("Convert to gray", isOn: $app.image.grayscale)
                    .font(TypeScale.body)
            }
            if !app.image.grayscale {
                adjustSlider("Brightness", value: $app.image.brightness, info: HelpText.brightnessContrast)
                adjustSlider("Contrast", value: $app.image.contrast, info: HelpText.brightnessContrast)
                adjustSlider("Saturation", value: $app.image.saturation, info: HelpText.saturation)
            }
            SettingRow(title: "Metadata", info: HelpText.stripMetadata) {
                Toggle("Strip EXIF / GPS", isOn: $app.image.stripMetadata)
                    .font(TypeScale.body)
            }
        }

        Card(title: "Border", systemImage: "square.on.square.dashed") {
            SettingRow(title: "Mode", info: HelpText.borderMode) {
                SegmentedControl(
                    options: BorderSettings.Mode.allCases,
                    selection: $app.image.border.mode,
                    label: { $0.rawValue })
            }
            switch app.image.border.mode {
            case .none:
                EmptyView()
            case .border:
                SettingRow(title: "Thickness") {
                    HStack(spacing: 6) {
                        IntField(value: $app.image.border.thickness)
                        Text("px").font(TypeScale.caption).foregroundColor(Palette.onSurfaceVariant)
                    }
                }
                SettingRow(title: "Color") {
                    HexColorField(hex: $app.image.border.colorHex)
                }
            case .padToCanvas:
                SettingRow(title: "Canvas") {
                    HStack(spacing: 6) {
                        IntField(value: $app.image.border.canvasWidth)
                        Text("×").foregroundColor(Palette.onSurfaceVariant)
                        IntField(value: $app.image.border.canvasHeight)
                    }
                }
                SettingRow(title: "Color") {
                    HexColorField(hex: $app.image.border.colorHex)
                }
            }
        }

        WatermarkSection()

        TransformSection(
            rotation: $app.image.rotation,
            flipH: $app.image.flipH,
            flipV: $app.image.flipV,
            cropEnabled: $app.image.cropEnabled,
            cropX: $app.image.cropX,
            cropY: $app.image.cropY,
            cropW: $app.image.cropW,
            cropH: $app.image.cropH)
    }

    /// Factor-based bulk resize: one multiplier applied to every added image, so a batch of mixed
    /// resolutions all shrink (or grow) by the same amount rather than being forced to one size.
    private struct ScaleFactorControls: View {
        @EnvironmentObject var app: AppState

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                SettingRow(title: "Factor", info: HelpText.imageScaleFactor) {
                    HStack(spacing: 10) {
                        Slider(value: $app.image.scaleFactor.snapped(to: 0.05), in: 0.05...4)
                            .frame(minWidth: 90, maxWidth: 180)
                        ValueTag(text: String(format: "%g×", app.image.scaleFactor), width: 52)
                    }
                }

                HStack(spacing: 6) {
                    ForEach(ImageSettings.commonScaleFactors, id: \.self) { preset in
                        Button(String(format: "%g×", preset)) {
                            app.image.scaleFactor = preset
                        }
                        .buttonStyle(TonalButtonStyle())
                    }
                }
                .padding(.leading, Metrics.labelColumn + 10)

                Text(note)
                    .font(TypeScale.caption)
                    .foregroundColor(Palette.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, Metrics.labelColumn + 10)
            }
        }

        /// Size of the first added image — from the probe cache when it's arrived, else read
        /// straight from the file header (cheap, no decode).
        private var sourceSize: PixelSize? {
            guard let url = app.stagedURLs.first else { return nil }
            return app.cachedSize(of: url) ?? AppState.pixelSize(of: url)
        }

        /// Real numbers for the batch, so "0.5×" isn't the only feedback.
        private var note: String {
            let factor = String(format: "%g×", app.image.scaleFactor)
            guard let size = sourceSize else {
                return
                    "Each image is multiplied by \(factor), so a batch of mixed sizes keeps its proportions. Add images to see the result."
            }
            // Mirrors the builder end-to-end, so crop/rotate/border are reflected too.
            let final = CommandBuilder.finalDimensions(source: size, settings: app.image)
            let head = "First image: \(size.width)×\(size.height) → \(final.width)×\(final.height)."
            let others = app.stagedURLs.count - 1
            guard others > 0 else { return head }
            return "\(head) The other \(others) image\(others == 1 ? "" : "s") scale by the same \(factor)."
        }
    }

    private func adjustSlider(_ title: String, value: Binding<Double>, info: String) -> some View {
        SettingRow(title: title, info: info) {
            HStack(spacing: 10) {
                Slider(value: value.snapped(), in: -100...100)
                    .frame(minWidth: 90, maxWidth: 180)
                ValueTag(text: "\(Int(value.wrappedValue))", width: 40)
            }
        }
    }
}
