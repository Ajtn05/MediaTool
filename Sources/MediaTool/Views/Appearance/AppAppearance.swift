import AppKit
import SwiftUI

extension View {
    /// Keep SwiftUI surfaces and AppKit controls in the same appearance.
    func appAppearance(_ colorScheme: ColorScheme?) -> some View {
        preferredColorScheme(colorScheme)
            .background(
                WindowAppearanceSync(colorScheme: colorScheme)
                    .frame(width: 0, height: 0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            )
    }
}

/// Native pop-up controls need the window appearance as well as SwiftUI's color scheme.
private struct WindowAppearanceSync: NSViewRepresentable {
    let colorScheme: ColorScheme?

    func makeNSView(context: Context) -> AppearanceProbe {
        let view = AppearanceProbe(frame: .zero)
        view.colorScheme = colorScheme
        return view
    }

    func updateNSView(_ view: AppearanceProbe, context: Context) {
        view.colorScheme = colorScheme
    }

    final class AppearanceProbe: NSView {
        var colorScheme: ColorScheme? {
            didSet { syncAppearance() }
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            syncAppearance()
        }

        private func syncAppearance() {
            guard let window else { return }
            // nil preserves automatic macOS appearance changes in System mode.
            let appearance = colorScheme.flatMap {
                NSAppearance(named: $0 == .dark ? .darkAqua : .aqua)
            }
            if window.appearance?.name != appearance?.name {
                window.appearance = appearance
            }
        }
    }
}
