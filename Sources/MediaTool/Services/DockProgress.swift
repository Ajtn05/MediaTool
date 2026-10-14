import AppKit

/// Draws conversion progress onto the Dock tile: a badge with the remaining count and a
/// progress bar across the bottom of the icon.
@MainActor
enum DockProgress {
    private static var progressView: DockTileProgressView?

    /// `progress` is 0…1; `remaining` is how many jobs are still queued or running.
    static func update(progress: Double, remaining: Int) {
        let tile = NSApp.dockTile

        tile.badgeLabel = remaining > 0 ? "\(remaining)" : nil

        if remaining > 0 {
            let view = existingOrNewView()
            view.progress = progress
            tile.contentView = view
        } else {
            tile.contentView = nil
            progressView = nil
        }
        tile.display()
    }

    /// Clears the badge and any custom drawing.
    static func clear() {
        let tile = NSApp.dockTile
        tile.badgeLabel = nil
        tile.contentView = nil
        progressView = nil
        tile.display()
    }

    private static func existingOrNewView() -> DockTileProgressView {
        if let progressView { return progressView }
        let view = DockTileProgressView(frame: NSRect(x: 0, y: 0, width: 128, height: 128))
        progressView = view
        return view
    }
}

/// Custom Dock tile content: the app icon plus a bordered progress bar.
private final class DockTileProgressView: NSView {
    var progress: Double = 0

    override func draw(_ dirtyRect: NSRect) {
        NSApp.applicationIconImage?.draw(in: bounds)

        let barHeight = bounds.height * 0.14
        let inset = bounds.width * 0.08
        let barRect = NSRect(
            x: inset,
            y: inset * 0.7,
            width: bounds.width - inset * 2,
            height: barHeight)

        // Track
        NSColor(hex: 0xF4F1EA).setFill()
        barRect.fill()

        // Fill
        let clamped = max(0, min(1, progress))
        var fillRect = barRect
        fillRect.size.width = barRect.width * clamped
        NSColor(hex: 0xC8FF00).setFill()
        fillRect.fill()

        // Border
        NSColor(hex: 0x111111).setStroke()
        let border = NSBezierPath(rect: barRect)
        border.lineWidth = max(2, bounds.width * 0.02)
        border.stroke()
    }
}
