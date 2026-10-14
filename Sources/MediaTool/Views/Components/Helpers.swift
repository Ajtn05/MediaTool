import AppKit
import SwiftUI

/// Copies a string to the system pasteboard.
func copyToPasteboard(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
}

/// Reveals a file in Finder.
func revealInFinder(_ url: URL) {
    NSWorkspace.shared.activateFileViewerSelecting([url])
}

/// Presents a folder-chooser panel and returns the selected directory.
func chooseFolder() -> URL? {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.prompt = "Choose"
    return panel.runModal() == .OK ? panel.url : nil
}

extension URL {
    /// A short display name for lists.
    var displayName: String { lastPathComponent }
}

extension Binding where Value == Double {
    /// Snaps a continuous slider value to whole steps *without* using `Slider(step:)`,
    /// which would make macOS draw a tick-mark rule under the track.
    func snapped(to step: Double = 1) -> Binding<Double> {
        Binding<Double>(
            get: { wrappedValue },
            set: { wrappedValue = (($0 / step).rounded()) * step }
        )
    }
}

// MARK: - Setting row

/// A labeled row that lays a control out to the right of a fixed-width caption.
/// Pass `info:` to show a tappable ⓘ button (and hover tooltip) explaining the setting.
struct SettingRow<Content: View>: View {
    let title: String
    var info: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: InterfaceStyle.current == .classic ? 10 : 12) {
            // Keep labels in a consistent leading column, like a macOS grouped settings pane.
            HStack(spacing: 4) {
                Text(InterfaceStyle.current == .classic ? title.uppercased() : title)
                    .font(TypeScale.label)
                    .tracking(InterfaceStyle.current == .classic ? 0.8 : 0)
                    .foregroundColor(Palette.onSurfaceVariant)
                if let info {
                    InfoButton(text: info)
                }
            }
            .frame(width: Metrics.labelColumn, alignment: .leading)
            content()
            Spacer(minLength: 0)
        }
    }
}

/// A small ⓘ button that reveals a description in a popover, and mirrors it as a hover tooltip.
struct InfoButton: View {
    let text: String
    @State private var showing = false

    var body: some View {
        Button {
            showing.toggle()
        } label: {
            Image(systemName: "info.circle")
                .font(TypeScale.caption)
                .foregroundColor(Palette.onSurfaceVariant.opacity(0.9))
        }
        .buttonStyle(.plain)
        .help(text)
        .popover(isPresented: $showing, arrowEdge: .bottom) {
            Text(text)
                .font(TypeScale.body)
                .foregroundColor(Palette.onSurface)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 290)
                .padding(16)
                .background(Palette.surface)
        }
    }
}

/// Value readout used beside sliders — monospaced so it doesn't jitter.
struct ValueTag: View {
    let text: String
    var width: CGFloat = 78

    var body: some View {
        Text(text)
            .font(.system(size: 11.5, weight: .medium, design: .monospaced))
            .foregroundColor(Palette.onSurface)
            .frame(width: width, alignment: .leading)
    }
}
