import SwiftUI

/// Preferences window (⌘,). Styled with the same components as the main window.
struct SettingsView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var tools: ToolLocator
    @EnvironmentObject var theme: ThemeStore
    @AppStorage("mediatool.appearance") private var appearanceRaw = Appearance.system.rawValue

    private var appearance: Binding<Appearance> {
        Binding(
            get: { Appearance(rawValue: appearanceRaw) ?? .system },
            set: { appearanceRaw = $0.rawValue }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: InterfaceStyle.current == .classic ? 14 : 16) {
                Card(title: "Appearance", systemImage: "paintbrush.fill") {
                    SettingRow(title: "Theme") {
                        SegmentedControl(
                            options: InterfaceStyle.allCases,
                            selection: $theme.style,
                            label: { $0.rawValue })
                    }
                    if theme.style == .modern {
                        SettingRow(title: "Appearance", info: HelpText.appearance) {
                            SegmentedControl(
                                options: Appearance.allCases,
                                selection: appearance,
                                label: { $0.rawValue },
                                symbol: { $0.symbol })
                        }
                    }
                    SettingRow(title: "Accent", info: HelpText.accentColor) {
                        HStack(spacing: 8) {
                            ForEach(
                                theme.style == .classic ? AccentChoice.allCases : AccentChoice.modernCases
                            ) { choice in
                                AccentSwatch(
                                    choice: choice,
                                    selected: (theme.style == .classic ? theme.classicAccent : theme.accent)
                                        == choice
                                ) {
                                    if theme.style == .classic {
                                        theme.classicAccent = choice
                                    } else {
                                        theme.accent = choice
                                    }
                                }
                            }
                        }
                    }
                    if theme.style == .classic {
                        Text("Classic keeps the original cream and black; its accent can change.")
                            .font(TypeScale.caption)
                            .foregroundColor(Palette.onSurfaceVariant)
                    }
                    Text("Applies immediately and is remembered between launches.")
                        .font(TypeScale.caption)
                        .foregroundColor(Palette.onSurfaceVariant)
                }

                Card(title: "Output Defaults", systemImage: "folder.fill") {
                    SettingRow(title: "Save to", info: HelpText.destination) {
                        UtilityPicker(
                            options: OutputDestination.allCases, selection: $app.destination,
                            label: { $0.rawValue }
                        )
                        .frame(width: 190, alignment: .leading)
                        .onChange(of: app.destination) { dest in
                            if dest == .customFolder {
                                if let folder = chooseFolder() {
                                    app.customFolder = folder
                                } else {
                                    app.destination = .sameAsSource
                                }
                            }
                        }
                    }
                    if app.destination == .customFolder, let folder = app.customFolder {
                        SettingRow(title: "Folder") {
                            Text(folder.path)
                                .font(TypeScale.monoSmall)
                                .foregroundColor(Palette.onSurfaceVariant)
                                .lineLimit(1).truncationMode(.head)
                        }
                    }
                    SettingRow(title: "Naming", info: HelpText.naming) {
                        SegmentedControl(
                            options: NamingMode.allCases,
                            selection: $app.naming,
                            label: { $0 == .suffix ? "Suffix" : "Rename" })
                    }
                    if app.naming == .suffix {
                        SettingRow(title: "Suffix", info: HelpText.suffix) {
                            TextField("-converted", text: $app.nameSuffix)
                                .font(TypeScale.mono)
                                .roundedField()
                                .frame(width: 150)
                        }
                    } else {
                        SettingRow(title: "Name") {
                            TextField("output", text: $app.customName)
                                .font(TypeScale.mono)
                                .roundedField()
                                .frame(width: 150)
                        }
                    }
                }

                Card(title: "Command-line Tools", systemImage: "terminal.fill") {
                    toolRow("ffmpeg", path: tools.tools.ffmpeg)
                    toolRow("ffprobe", path: tools.tools.ffprobe)
                    toolRow("magick", path: tools.tools.magick)
                    toolRow("ghostscript", path: tools.tools.ghostscript, optional: "needed for PDF output")

                    HStack {
                        Button("Re-check") { tools.refresh() }
                            .buttonStyle(TonalButtonStyle())
                        Spacer()
                    }
                    .padding(.top, 2)
                }
            }
            .padding(Metrics.gutter)
        }
        .background(Palette.background)
        .materialControls()
        .frame(width: 520, height: 580)
        .id(theme.identity)
    }

    private func toolRow(_ name: String, path: String?, optional: String? = nil) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: path != nil ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 13))
                .foregroundColor(path != nil ? Palette.accentText : Palette.error)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(Palette.onSurface)
                Text(path ?? "not found\(optional.map { " — \($0)" } ?? "")")
                    .font(TypeScale.monoSmall)
                    .foregroundColor(Palette.onSurfaceVariant)
                    .lineLimit(1).truncationMode(.head)
            }
            Spacer()
        }
    }
}

/// One selectable accent colour. Fixed set — no free-form picker, so every option stays
/// legible against the palette.
struct AccentSwatch: View {
    let choice: AccentChoice
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(InterfaceStyle.current == .classic ? choice.classicColor : choice.swatchColor)
                .frame(width: 24, height: 24)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(
                            InterfaceStyle.current == .classic ? choice.classicInk : Palette.onPrimary
                        )
                        .opacity(selected ? 1 : 0)
                )
                .overlay(Circle().strokeBorder(Palette.outlineVariant, lineWidth: Metrics.hairline))
                // A ring in the gap, so the current choice reads at a glance.
                .padding(3)
                .overlay(Circle().strokeBorder(selected ? Palette.primary : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .help(choice.label)
    }
}
