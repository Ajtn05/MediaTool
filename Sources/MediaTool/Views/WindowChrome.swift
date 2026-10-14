import AppKit
import SwiftUI

/// Hosts a SwiftUI view *inside* the window's title bar, on the same row as the traffic lights,
/// and paints the window background with our canvas colour.
///
/// Both are needed because `.windowStyle(.hiddenTitleBar)` hides the title but still lays SwiftUI
/// content out *below* the title bar strip — anything placed in the normal view hierarchy ends up
/// under the traffic lights, never beside them. A title bar accessory is the supported way to put
/// content on that row. Setting the window background keeps the strip from showing the default
/// system grey against our paper/ink canvas.

/// Identifies the accessory we own, so repeat installs replace rather than stack.
/// File scope because a generic type can't hold static stored properties.
private let mediaToolAccessoryID = NSUserInterfaceItemIdentifier("MediaToolTitlebarAccessory")

struct WindowChrome<Accessory: View>: NSViewRepresentable {
    let accessory: Accessory
    /// Height of the title bar row; the accessory is centred in it.
    var height: CGFloat = 28

    func makeNSView(context: Context) -> NSView {
        let probe = NSView(frame: .zero)
        // The view has no window yet during make; configure on the next runloop pass.
        DispatchQueue.main.async { configure(probe, coordinator: context.coordinator) }
        return probe
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { configure(nsView, coordinator: context.coordinator) }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var installed = false
    }

    private func configure(_ view: NSView, coordinator: Coordinator) {
        guard let window = view.window else { return }

        window.backgroundColor = Palette.nsBackground

        guard !coordinator.installed else { return }
        coordinator.installed = true

        // This representable is torn down and rebuilt whenever the view tree is re-keyed (the
        // accent switcher does exactly that), and each rebuild brings a fresh coordinator. Clear
        // any accessory a previous instance left behind or they stack up, one wordmark per change.
        for index in window.titlebarAccessoryViewControllers.indices.reversed()
        where window.titlebarAccessoryViewControllers[index].identifier == mediaToolAccessoryID {
            window.removeTitlebarAccessoryViewController(at: index)
        }

        let hosting = NSHostingView(rootView: accessory)
        hosting.frame = NSRect(
            x: 0, y: 0,
            width: max(hosting.fittingSize.width, 1),
            height: height)

        let controller = NSTitlebarAccessoryViewController()
        controller.identifier = mediaToolAccessoryID
        controller.view = hosting
        // .leading puts the view immediately after the traffic lights, on the same row.
        controller.layoutAttribute = .leading
        window.addTitlebarAccessoryViewController(controller)
    }
}

/// The app mark and name, sized for the title bar row.
struct Wordmark: View {
    var body: some View {
        HStack(spacing: 8) {
            Text(InterfaceStyle.current == .classic ? "MEDIATOOL" : "Media Tool")
                .font(
                    InterfaceStyle.current == .classic
                        ? .custom("Arial Black", size: 10.5) : .system(size: 13, weight: .semibold)
                )
                .tracking(InterfaceStyle.current == .classic ? 2.5 : 0)
                .foregroundColor(
                    InterfaceStyle.current == .classic ? Palette.onSurfaceVariant : Palette.onSurface)
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
    }
}
