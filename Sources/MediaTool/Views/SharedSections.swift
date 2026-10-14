import SwiftUI

// MARK: - Preset bar

/// Compact preset controls for the active mode: apply, save, delete.
struct PresetBar: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var presets: PresetStore

    @State private var showingSave = false
    @State private var newName = ""

    var body: some View {
        let modePresets = presets.presets(for: app.mode)
        let userPresets = modePresets.filter { !$0.builtIn }

        HStack(spacing: 10) {
            SectionHeader("Presets", color: Palette.onSurfaceVariant)

            Menu {
                if modePresets.isEmpty {
                    Text("No presets")
                } else {
                    ForEach(modePresets) { preset in
                        Button(preset.name) { presets.apply(preset, to: app) }
                    }
                }
                Divider()
                Button("Save Current…") {
                    newName = ""
                    showingSave = true
                }
                if !userPresets.isEmpty {
                    Menu("Delete") {
                        ForEach(userPresets) { preset in
                            Button(preset.name, role: .destructive) { presets.delete(preset) }
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    if InterfaceStyle.current == .classic {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Palette.onSurface)
                    }
                    Text(InterfaceStyle.current == .classic ? "LOAD / SAVE" : "Load / Save")
                        .font(TypeScale.smallButton)
                        .tracking(InterfaceStyle.current == .classic ? 1.2 : 0)
                        .foregroundStyle(
                            InterfaceStyle.current == .classic ? Palette.onSurface : Palette.onSurfaceVariant)
                    if InterfaceStyle.current == .modern {
                        Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
                    }
                }
                .foregroundColor(
                    InterfaceStyle.current == .classic ? Palette.onSurface : Palette.onSurfaceVariant)
            }
            .menuStyle(.borderlessButton)
            .tint(InterfaceStyle.current == .classic ? Palette.onSurface : Palette.primary)
            .menuIndicator(.hidden)
            .fixedSize()
            .padding(.horizontal, InterfaceStyle.current == .classic ? 11 : 12)
            .padding(.vertical, InterfaceStyle.current == .classic ? 4 : 5)
            .background(RoundedRectangle(cornerRadius: Metrics.controlRadius).fill(Palette.controlBackground))
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.controlRadius)
                    .strokeBorder(
                        InterfaceStyle.current == .classic ? Palette.outline : .clear,
                        lineWidth: Metrics.hairline)
            )

            Spacer()
        }
        .sheet(isPresented: $showingSave) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Save \(app.mode.rawValue.lowercased()) preset")
                    .font(TypeScale.title)
                    .foregroundColor(Palette.onSurface)
                TextField("Preset name", text: $newName)
                    .roundedField()
                    .frame(width: 260)
                HStack(spacing: 8) {
                    Spacer()
                    Button("Cancel") { showingSave = false }
                        .buttonStyle(TextButtonStyle())
                    Button("Save") {
                        presets.save(name: newName, from: app)
                        showingSave = false
                    }
                    .buttonStyle(FilledButtonStyle())
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(22)
            .background(Palette.background)
            .materialControls()
        }
    }
}

// MARK: - Trim section (video + audio)

struct TrimSection: View {
    @Binding var enabled: Bool
    @Binding var start: String
    @Binding var end: String

    var body: some View {
        Card(title: "Trim", systemImage: "scissors") {
            Toggle("Trim to a time range", isOn: $enabled)
                .font(TypeScale.bodyEmphasis)
            if enabled {
                SettingRow(title: "Start", info: HelpText.trim) {
                    TimeField(text: $start)
                }
                SettingRow(title: "End") {
                    TimeField(text: $end)
                }
            }
        }
    }
}

struct TimeField: View {
    @Binding var text: String
    var body: some View {
        TextField("00:00:00", text: $text)
            .font(TypeScale.mono)
            .roundedField()
            .frame(width: 104)
    }
}

// MARK: - Speed section (video + audio)

struct SpeedSection: View {
    @Binding var settings: SpeedSettings

    var body: some View {
        Card(title: "Speed", systemImage: "gauge.with.needle") {
            Toggle("Change playback speed", isOn: $settings.enabled)
                .font(TypeScale.bodyEmphasis)
            if settings.enabled {
                SettingRow(title: "Rate", info: HelpText.speedRate) {
                    HStack(spacing: 10) {
                        Slider(value: $settings.rate.snapped(to: 0.05), in: 0.25...4)
                            .frame(minWidth: 90, maxWidth: 190)
                        ValueTag(text: String(format: "%.2f×", settings.rate), width: 60)
                    }
                }
                HStack(spacing: 6) {
                    ForEach([0.5, 1.0, 1.5, 2.0], id: \.self) { preset in
                        Button(preset == 1.0 ? "1×" : String(format: "%g×", preset)) {
                            settings.rate = preset
                        }
                        .buttonStyle(TonalButtonStyle())
                    }
                }
                .padding(.leading, Metrics.labelColumn + 10)
            }
        }
    }
}

// MARK: - Transform section (video + image)

struct TransformSection: View {
    @Binding var rotation: Rotation
    @Binding var flipH: Bool
    @Binding var flipV: Bool
    @Binding var cropEnabled: Bool
    @Binding var cropX: Int
    @Binding var cropY: Int
    @Binding var cropW: Int
    @Binding var cropH: Int

    var body: some View {
        Card(title: "Transform", systemImage: "crop.rotate") {
            SettingRow(title: "Rotate", info: HelpText.rotation) {
                SegmentedControl(
                    options: Rotation.allCases,
                    selection: $rotation,
                    label: { $0.label })
            }
            SettingRow(title: "Flip", info: HelpText.flip) {
                HStack(spacing: 14) {
                    Toggle("Horizontal", isOn: $flipH)
                    Toggle("Vertical", isOn: $flipV)
                }
                .font(TypeScale.body)
            }
            Toggle("Crop", isOn: $cropEnabled)
                .font(TypeScale.bodyEmphasis)
            if cropEnabled {
                SettingRow(title: "Size", info: HelpText.crop) {
                    HStack(spacing: 6) {
                        IntField(value: $cropW)
                        Text("×").foregroundColor(Palette.onSurfaceVariant)
                        IntField(value: $cropH)
                    }
                }
                SettingRow(title: "Offset") {
                    HStack(spacing: 6) {
                        IntField(value: $cropX)
                        Text(",").foregroundColor(Palette.onSurfaceVariant)
                        IntField(value: $cropY)
                    }
                }
            }
        }
    }
}
