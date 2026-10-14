import SwiftUI

/// Crossed hammer and brush geometry shared by the app badge and menu bar mark.
private enum LogoArtwork {
    static let main: [[CGPoint]] = [
        // Flat striking face and split claw on a traditional hammer head.
        [
            p(11, 34), p(16, 29), p(20, 33), p(34, 19), p(38, 17), p(42, 19),
            p(44, 16), p(47, 16), p(45, 20), p(42, 23), p(48, 22), p(49, 25),
            p(42, 27), p(38, 26), p(20, 44), p(16, 40), p(11, 39),
        ],
        // The break lets the brush pass in front of the hammer handle.
        [p(28, 32), p(32, 28), p(47, 43), p(43, 47)],
        [p(58, 54), p(82, 78), p(78, 82), p(54, 58)],
        // Brush handle, ferrule, and bristles all follow the opposite 45° axis.
        [p(18, 78), p(22, 82), p(60, 44), p(56, 40)],
        [p(56, 39), p(63, 46), p(70, 39), p(63, 32)],
        [
            p(64, 30), p(72, 22), p(78, 18), p(84, 16),
            p(82, 22), p(78, 28), p(71, 37),
        ],
    ]

    /// Slightly thicker handles and simpler bristles survive the 18-point menu bar size.
    static let menuBar: [[CGPoint]] = [
        main[0],
        [p(27.5, 32.5), p(32.5, 27.5), p(47.5, 42.5), p(42.5, 47.5)],
        [p(58, 53), p(82.5, 77.5), p(77.5, 82.5), p(53, 58)],
        [p(17.5, 77.5), p(22.5, 82.5), p(60.5, 44.5), p(55.5, 39.5)],
        [p(55.5, 39), p(63, 46.5), p(70.5, 39), p(63, 31.5)],
        [
            p(63, 31), p(71, 23), p(77, 19), p(85, 15),
            p(83, 23), p(78, 30), p(70, 38),
        ],
    ]

    private static func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    static func draw(
        _ shapes: [[CGPoint]], center: CGPoint, scale: CGFloat,
        color: Color, in context: GraphicsContext, size: CGSize
    ) {
        let unit = min(size.width, size.height) / 100
        let ink = GraphicsContext.Shading.color(color)

        for points in shapes {
            guard let first = points.first else { continue }
            func place(_ point: CGPoint) -> CGPoint {
                CGPoint(
                    x: (50 + (point.x - center.x) * scale) * unit,
                    y: (50 + (point.y - center.y) * scale) * unit)
            }

            var path = Path()
            path.move(to: place(first))
            for point in points.dropFirst() { path.addLine(to: place(point)) }
            path.closeSubpath()
            context.fill(path, with: ink)
        }
    }
}

struct LogoMark: View {
    var size: CGFloat = 34

    var body: some View {
        Canvas { context, canvasSize in
            LogoArtwork.draw(
                LogoArtwork.main, center: CGPoint(x: 47.5, y: 49),
                scale: 0.96, color: Palette.onPrimary,
                in: context, size: canvasSize)
        }
        .background(Palette.primary)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
        .frame(width: size, height: size)
    }
}

/// Monochrome menu bar variation without the colored badge.
struct MenuBarLogoMark: View {
    var isRunning: Bool
    var size: CGFloat = 18

    var body: some View {
        Canvas { context, canvasSize in
            LogoArtwork.draw(
                LogoArtwork.menuBar, center: CGPoint(x: 48, y: 48.75),
                scale: 1.1, color: .primary,
                in: context, size: canvasSize)
            if isRunning {
                let dot = CGRect(
                    x: canvasSize.width * 0.46,
                    y: 0,
                    width: canvasSize.width * 0.12,
                    height: canvasSize.height * 0.12)
                context.fill(Path(ellipseIn: dot), with: .color(.primary))
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(isRunning ? "Media Tool, converting" : "Media Tool")
    }
}
