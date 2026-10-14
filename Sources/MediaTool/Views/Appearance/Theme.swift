import AppKit
import SwiftUI

// MARK: - Appearance

/// User-selectable appearance, persisted in Settings.
enum Appearance: String, CaseIterable, Identifiable, Codable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    /// nil means "follow macOS".
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var symbol: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }
}

// MARK: - Accent

/// The original paper and ink interface is kept as an optional style.
enum InterfaceStyle: String, CaseIterable, Identifiable {
    case modern = "Modern"
    case classic = "Classic"

    var id: String { rawValue }
    static let storageKey = "mediatool.interfaceStyle"

    static var current: InterfaceStyle {
        InterfaceStyle(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .modern
    }
}

/// Accent colours for controls. Modern uses macOS colours on neutral surfaces.
enum AccentChoice: String, CaseIterable, Identifiable, Codable {
    case lime, blue, teal, green, yellow, orange, pink, purple

    var id: String { rawValue }

    var seed: UInt32 {
        switch self {
        case .lime: return 0xC8FF00
        case .blue: return 0x1A73E8
        case .teal: return 0x00A099
        case .green: return 0x34A853
        case .yellow: return 0xF2B01B
        case .orange: return 0xE8710A
        case .pink: return 0xE52592
        case .purple: return 0x8E45E0
        }
    }

    /// Lime belongs to the original Classic palette; Modern retains its previous seven choices.
    static var modernCases: [AccentChoice] { allCases.filter { $0 != .lime } }

    var label: String { rawValue.capitalized }

    var nativeColor: NSColor {
        switch self {
        case .lime: return NSColor(hex: seed)
        case .blue: return .systemBlue
        case .teal: return .systemTeal
        case .green: return .systemGreen
        case .yellow: return .systemYellow
        case .orange: return .systemOrange
        case .pink: return .systemPink
        case .purple: return .systemPurple
        }
    }

    var swatchColor: Color { Color(nsColor: nativeColor) }

    var classicColor: Color { Color(hex: seed) }

    var classicContainer: Color {
        let red = Double((seed >> 16) & 0xFF) / 255
        let green = Double((seed >> 8) & 0xFF) / 255
        let blue = Double(seed & 0xFF) / 255
        return Color(
            .sRGB, red: 0.7 + red * 0.3,
            green: 0.7 + green * 0.3,
            blue: 0.7 + blue * 0.3, opacity: 1)
    }

    /// Keep selected labels legible on both bright and dark Classic accent fills.
    var classicInk: Color {
        func linear(_ byte: UInt32) -> Double {
            let value = Double(byte) / 255
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        let luminance =
            0.2126 * linear((seed >> 16) & 0xFF)
            + 0.7152 * linear((seed >> 8) & 0xFF)
            + 0.0722 * linear(seed & 0xFF)
        return luminance > 0.179 ? .black : .white
    }

    static let storageKey = "mediatool.accent"
    static let classicStorageKey = "mediatool.classicAccent"

    /// Read straight from defaults so `Palette` stays a plain static lookup.
    static var current: AccentChoice {
        AccentChoice(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .blue
    }

    static var classicCurrent: AccentChoice {
        AccentChoice(rawValue: UserDefaults.standard.string(forKey: classicStorageKey) ?? "") ?? .lime
    }
}

/// Publishes accent changes so views re-render; the value itself lives in UserDefaults.
@MainActor
final class ThemeStore: ObservableObject {
    @Published var accent: AccentChoice {
        didSet { UserDefaults.standard.set(accent.rawValue, forKey: AccentChoice.storageKey) }
    }
    @Published var classicAccent: AccentChoice {
        didSet { UserDefaults.standard.set(classicAccent.rawValue, forKey: AccentChoice.classicStorageKey) }
    }
    @Published var style: InterfaceStyle {
        didSet { UserDefaults.standard.set(style.rawValue, forKey: InterfaceStyle.storageKey) }
    }

    var identity: String { "\(style.rawValue)-\(accent.rawValue)-\(classicAccent.rawValue)" }

    init() {
        accent = AccentChoice.current
        classicAccent = AccentChoice.classicCurrent
        style = InterfaceStyle.current
    }
}

// MARK: - Palette

/// Neutral macOS surfaces with accent colour reserved for controls and navigation icons.
enum Palette {
    static var background: Color { Color(nsColor: nsBackground) }
    static var workspace: Color {
        InterfaceStyle.current == .classic ? background : neutral(light: 0xFFFFFF, dark: 0x1E1E1E)
    }
    static var surface: Color {
        InterfaceStyle.current == .classic ? Color(hex: 0xFFFDF8) : neutral(light: 0xFFFFFF, dark: 0x322E33)
    }
    static var surfaceVariant: Color {
        InterfaceStyle.current == .classic ? Color(hex: 0xEBE9E1) : neutral(light: 0xF0EFF2, dark: 0x252326)
    }
    static var controlBackground: Color {
        InterfaceStyle.current == .classic ? surface : neutral(light: 0xE9E8EC, dark: 0x403B41)
    }
    static var checkboxBackground: Color {
        InterfaceStyle.current == .classic ? Color(hex: 0xE5E3DE) : controlBackground
    }
    static var selection: Color { neutral(light: 0xD8D5DE, dark: 0x514651) }

    static var onSurface: Color {
        InterfaceStyle.current == .classic ? Color(hex: 0x111111) : Color(nsColor: .labelColor)
    }
    static var onSurfaceVariant: Color {
        InterfaceStyle.current == .classic ? Color(hex: 0x696862) : Color(nsColor: .secondaryLabelColor)
    }
    static var outline: Color {
        InterfaceStyle.current == .classic ? Color(hex: 0x111111) : neutral(light: 0xC9C6CD, dark: 0x514B53)
    }
    static var outlineVariant: Color {
        InterfaceStyle.current == .classic ? Color(hex: 0x111111) : neutral(light: 0xDEDBE1, dark: 0x413B43)
    }

    static var primary: Color {
        InterfaceStyle.current == .classic
            ? AccentChoice.classicCurrent.classicColor : AccentChoice.current.swatchColor
    }
    static var accentText: Color { InterfaceStyle.current == .classic ? onSurface : primary }
    static var onPrimary: Color {
        InterfaceStyle.current == .classic
            ? AccentChoice.classicCurrent.classicInk : (AccentChoice.current == .yellow ? .black : .white)
    }
    static var primaryContainer: Color {
        InterfaceStyle.current == .classic
            ? AccentChoice.classicCurrent.classicContainer : primary.opacity(0.12)
    }
    static var onPrimaryContainer: Color { onSurface }
    static var secondaryContainer: Color {
        InterfaceStyle.current == .classic ? AccentChoice.classicCurrent.classicColor : controlBackground
    }
    static var onSecondaryContainer: Color {
        InterfaceStyle.current == .classic ? AccentChoice.classicCurrent.classicInk : onSurface
    }

    static var error: Color {
        InterfaceStyle.current == .classic ? Color(hex: 0xB3261E) : Color(nsColor: .systemRed)
    }
    static let shadow = adaptive(
        light: NSColor(white: 0, alpha: 0.14),
        dark: NSColor(white: 0, alpha: 0.38))

    /// AppKit-side canvas, so the title bar strip and the SwiftUI content read as one surface.
    static var nsBackground: NSColor {
        if InterfaceStyle.current == .classic { return NSColor(hex: 0xF4F1EA) }
        return nsAdaptive(light: NSColor(hex: 0xF5F4F6), dark: NSColor(hex: 0x29252B))
    }

    static func adaptive(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: nsAdaptive(light: light, dark: dark))
    }

    private static func nsAdaptive(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        }
    }

    private static func neutral(light: UInt32, dark: UInt32) -> Color {
        adaptive(light: NSColor(hex: light), dark: NSColor(hex: dark))
    }
}

// MARK: - Geometry

/// Shared geometry, on an 8-point grid: soft corners, hairline edges, generous padding.
enum Metrics {
    static var hairline: CGFloat { InterfaceStyle.current == .classic ? 1.5 : 1 }
    static var gutter: CGFloat { InterfaceStyle.current == .classic ? 14 : 16 }
    static let cardPadding: CGFloat = 14
    static var cardRadius: CGFloat { InterfaceStyle.current == .classic ? 0 : 12 }
    static var controlRadius: CGFloat { InterfaceStyle.current == .classic ? 0 : 7 }
    /// Width of the caption column in SettingRow, so every row lines up.
    static var labelColumn: CGFloat { InterfaceStyle.current == .classic ? 124 : 104 }
}

// MARK: - Type scale

/// The handful of text roles the app uses. Sizes track the macOS system font, so the app reads
/// as a native utility in Modern and retains its original typography in Classic.
enum TypeScale {
    static var title: Font {
        InterfaceStyle.current == .classic
            ? .custom("Arial Black", size: 12) : .system(size: 15, weight: .semibold)
    }
    static var sectionTitle: Font {
        InterfaceStyle.current == .classic
            ? .custom("Arial Black", size: 10.5) : .system(size: 13, weight: .semibold)
    }
    static var body: Font { .system(size: InterfaceStyle.current == .classic ? 11 : 12.5, weight: .regular) }
    static var bodyEmphasis: Font {
        .system(size: InterfaceStyle.current == .classic ? 11 : 12.5, weight: .medium)
    }
    static var label: Font {
        InterfaceStyle.current == .classic
            ? .custom("Arial Black", size: 9.5) : .system(size: 12, weight: .regular)
    }
    static var caption: Font { .system(size: InterfaceStyle.current == .classic ? 10 : 11, weight: .regular) }
    static var button: Font {
        InterfaceStyle.current == .classic
            ? .custom("Arial Black", size: 10.5) : .system(size: 12.5, weight: .medium)
    }
    static var smallButton: Font {
        InterfaceStyle.current == .classic
            ? .custom("Arial Black", size: 9.5) : .system(size: 11.5, weight: .medium)
    }
    static var mono: Font {
        .system(size: InterfaceStyle.current == .classic ? 10.5 : 11.5, design: .monospaced)
    }
    static var monoSmall: Font {
        .system(size: InterfaceStyle.current == .classic ? 10 : 10.5, design: .monospaced)
    }
}

// MARK: - Color helpers

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }

    /// "#RRGGBB" for passing to ImageMagick.
    var hexString: String {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? .black
        let r = Int((ns.redComponent * 255).rounded())
        let g = Int((ns.greenComponent * 255).rounded())
        let b = Int((ns.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
