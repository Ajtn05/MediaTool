import AppKit
import SwiftUI

/// Logo overlay controls. Fine positioning happens by dragging on the preview; this card
/// covers picking the logo, its size and opacity, and nine quick anchors.
struct WatermarkSection: View {
    @EnvironmentObject var app: AppState

    private var wm: Binding<WatermarkSettings> { $app.image.watermark }

    var body: some View {
        Card(title: "Watermark", systemImage: "signature") {
            Toggle("Add a logo overlay", isOn: wm.enabled)
                .font(TypeScale.bodyEmphasis)

            if app.image.watermark.enabled {
                SettingRow(title: "Logo", info: HelpText.watermarkLogo) {
                    HStack(spacing: 8) {
                        Button(app.image.watermark.logoPath.isEmpty ? "Choose…" : "Replace…") {
                            if let url = chooseImageFile() {
                                app.image.watermark.logoPath = url.path
                            }
                        }
                        .buttonStyle(TonalButtonStyle())

                        if let url = app.image.watermark.logoURL {
                            Text(url.lastPathComponent)
                                .font(TypeScale.monoSmall)
                                .foregroundColor(Palette.onSurfaceVariant)
                                .lineLimit(1).truncationMode(.middle)
                            Button {
                                app.image.watermark.logoPath = ""
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(Palette.onSurfaceVariant)
                            }
                            .buttonStyle(.plain)
                            .help("Remove logo")
                        }
                    }
                }

                if app.image.watermark.logoPath.isEmpty {
                    Text("Choose a logo — PNG with transparency works best.")
                        .font(TypeScale.caption)
                        .foregroundColor(Palette.onSurfaceVariant)
                } else {
                    SettingRow(title: "Size", info: HelpText.watermarkScale) {
                        HStack(spacing: 10) {
                            Slider(value: wm.scalePercent.snapped(), in: 2...60)
                                .frame(minWidth: 90, maxWidth: 180)
                            ValueTag(text: "\(Int(app.image.watermark.scalePercent))% w", width: 58)
                        }
                    }

                    SettingRow(title: "Opacity", info: HelpText.watermarkOpacity) {
                        HStack(spacing: 10) {
                            Slider(value: wm.opacity.snapped(), in: 0...100)
                                .frame(minWidth: 90, maxWidth: 180)
                            ValueTag(text: "\(Int(app.image.watermark.opacity))%", width: 44)
                        }
                    }

                    SettingRow(title: "Position", info: HelpText.watermarkPosition) {
                        AnchorGrid(normX: wm.normX, normY: wm.normY)
                    }

                    Text("Drag the logo on the preview above for exact placement.")
                        .font(TypeScale.caption)
                        .foregroundColor(Palette.onSurfaceVariant)
                }
            }
        }
    }

    /// Image-only open panel for picking the logo.
    private func chooseImageFile() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        panel.prompt = "Choose"
        return panel.runModal() == .OK ? panel.url : nil
    }
}

/// Nine-square quick anchor picker (corners, edges, centre).
struct AnchorGrid: View {
    @Binding var normX: Double
    @Binding var normY: Double

    private let stops: [Double] = [0, 0.5, 1]

    var body: some View {
        VStack(spacing: 4) {
            ForEach(stops, id: \.self) { y in
                HStack(spacing: 4) {
                    ForEach(stops, id: \.self) { x in
                        let active = isNear(normX, x) && isNear(normY, y)
                        Button {
                            normX = x
                            normY = y
                        } label: {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(active ? Palette.primary : Palette.surfaceVariant)
                                .frame(width: 20, height: 15)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .strokeBorder(
                                            active ? Color.clear : Palette.outlineVariant,
                                            lineWidth: Metrics.hairline)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    /// The drag handle sets arbitrary values, so highlight the nearest anchor loosely.
    private func isNear(_ value: Double, _ target: Double) -> Bool {
        abs(value - target) < 0.02
    }
}
