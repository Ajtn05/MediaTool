import AppKit
import SwiftUI

// MARK: - Pop-up menus

/// Classic uses a flat gray pop-up; Modern keeps the native macOS picker.
struct UtilityPicker<Option: Hashable & Identifiable>: View {
    let options: [Option]
    @Binding var selection: Option
    var label: (Option) -> String

    var body: some View {
        if InterfaceStyle.current == .classic {
            Menu {
                ForEach(options) { option in
                    Button {
                        selection = option
                    } label: {
                        if option == selection {
                            Label(label(option), systemImage: "checkmark")
                        } else {
                            Text(label(option))
                        }
                    }
                }
            } label: {
                Text(label(selection))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .font(.system(size: 13))
            .foregroundStyle(Palette.onSurface)
            .tint(Palette.onSurface)
            .frame(width: classicLabelWidth, alignment: .leading)
            .padding(.leading, 10)
            .padding(.trailing, 28)
            .padding(.vertical, 5)
            .background(Palette.surfaceVariant, in: RoundedRectangle(cornerRadius: 6))
            .overlay(alignment: .trailing) {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Palette.onSurfaceVariant)
                    .padding(.trailing, 10)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        } else {
            Picker("", selection: $selection) {
                ForEach(options) { option in
                    Text(label(option)).tag(option)
                }
            }
            .labelsHidden()
        }
    }

    private var classicLabelWidth: CGFloat {
        options.map {
            // The native borderless menu reserves internal insets beyond its text width.
            (label($0) as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 13)]).width + 24
        }.max() ?? 0
    }
}

// MARK: - Card

/// Modern sections use a heading above a quiet grouped surface; Classic keeps its outlined box.
struct Card<Content: View>: View {
    var title: String? = nil
    var systemImage: String? = nil
    /// Fills the card with the accent container instead of the plain surface — used for
    /// notices that need to pull rank over the settings around them.
    var accented: Bool = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        if InterfaceStyle.current == .classic {
            classicCard
        } else {
            VStack(alignment: .leading, spacing: 10) {
                if let title {
                    SectionHeader(title)
                        .padding(.leading, 12)
                }
                VStack(alignment: .leading, spacing: 14) {
                    content()
                }
                .padding(Metrics.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    accented ? Palette.primaryContainer : Palette.surface,
                    in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
            }
        }
    }

    private var classicCard: some View {
        VStack(alignment: .leading, spacing: InterfaceStyle.current == .classic ? 10 : 12) {
            if let title {
                HStack(spacing: 7) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(
                                .system(
                                    size: InterfaceStyle.current == .classic ? 11.5 : 12,
                                    weight: InterfaceStyle.current == .classic ? .heavy : .medium)
                            )
                            .foregroundColor(accented ? Palette.onPrimaryContainer : Palette.accentText)
                    }
                    SectionHeader(title, color: accented ? Palette.onPrimaryContainer : Palette.onSurface)
                }
            }
            content()
        }
        .padding(Metrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                .fill(accented ? Palette.primaryContainer : Palette.surface)
                .shadow(color: Palette.shadow, radius: InterfaceStyle.current == .classic ? 0 : 3, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                .strokeBorder(Palette.outlineVariant, lineWidth: Metrics.hairline)
        )
    }
}

/// Sentence-case section title.
struct SectionHeader: View {
    let text: String
    var color: Color = Palette.onSurface

    init(_ text: String, color: Color = Palette.onSurface) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(InterfaceStyle.current == .classic ? text.uppercased() : text)
            .font(TypeScale.sectionTitle)
            .tracking(InterfaceStyle.current == .classic ? 2 : 0)
            .foregroundColor(color)
    }
}

// MARK: - Buttons

/// Primary action with a native accent fill, a pressed state, and a neutral disabled state.
struct FilledButtonStyle: ButtonStyle {
    var tint: Color = Palette.primary
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let classic = InterfaceStyle.current == .classic
        return configuration.label
            .font(TypeScale.button)
            .foregroundColor(!classic && !isEnabled ? Palette.onSurfaceVariant : Palette.onPrimary)
            .padding(.horizontal, classic ? 16 : 18)
            .padding(.vertical, classic ? 7 : 8)
            .background(
                RoundedRectangle(cornerRadius: classic ? 0 : Metrics.controlRadius).fill(
                    !classic && !isEnabled ? Palette.controlBackground : tint)
            )
            .overlay(
                RoundedRectangle(cornerRadius: classic ? 0 : Metrics.controlRadius).strokeBorder(
                    classic ? Palette.outline : .clear, lineWidth: Metrics.hairline)
            )
            .overlay(
                RoundedRectangle(cornerRadius: classic ? 0 : Metrics.controlRadius).fill(
                    Palette.onPrimary.opacity(pressed ? 0.16 : 0))
            )
            .animation(.easeOut(duration: 0.08), value: pressed)
    }
}

/// Secondary action on a neutral rounded surface (Clear, Re-check, Cancel).
struct TonalButtonStyle: ButtonStyle {
    var destructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let classic = InterfaceStyle.current == .classic
        let foreground =
            destructive ? Palette.error : (classic ? Palette.onSurface : Palette.onSecondaryContainer)
        return configuration.label
            .font(TypeScale.smallButton)
            .foregroundColor(foreground)
            .padding(.horizontal, classic ? 11 : 12)
            .padding(.vertical, classic ? 4 : 5)
            .background(
                RoundedRectangle(cornerRadius: classic ? 0 : Metrics.controlRadius)
                    .fill(
                        destructive
                            ? Palette.error.opacity(0.12)
                            : (classic ? Palette.surface : Palette.secondaryContainer))
            )
            .overlay(
                RoundedRectangle(cornerRadius: classic ? 0 : Metrics.controlRadius).strokeBorder(
                    classic ? Palette.outline : .clear, lineWidth: Metrics.hairline)
            )
            .overlay(
                RoundedRectangle(cornerRadius: classic ? 0 : Metrics.controlRadius).fill(
                    foreground.opacity(pressed ? 0.12 : 0))
            )
            .animation(.easeOut(duration: 0.08), value: pressed)
    }
}

/// Lowest-emphasis action: label only, accent-coloured, with a state layer on press.
struct TextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let classic = InterfaceStyle.current == .classic
        return configuration.label
            .font(TypeScale.smallButton)
            .foregroundColor(classic ? Palette.onSurface : Palette.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: classic ? 0 : Metrics.controlRadius).fill(
                    Palette.primary.opacity(pressed ? 0.14 : 0))
            )
            .animation(.easeOut(duration: 0.08), value: pressed)
    }
}

// MARK: - Segmented control

/// Compact inset segments with an accent-filled selection in Modern.
struct SegmentedControl<T: Hashable & Identifiable>: View {
    let options: [T]
    @Binding var selection: T
    var label: (T) -> String
    var symbol: ((T) -> String)? = nil

    var body: some View {
        let classic = InterfaceStyle.current == .classic
        HStack(spacing: classic ? 0 : 2) {
            ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                let active = option == selection
                Button {
                    selection = option
                } label: {
                    HStack(spacing: 5) {
                        if let symbol {
                            Image(systemName: symbol(option)).font(
                                .system(size: 10, weight: classic ? .bold : .medium))
                        }
                        Text(classic ? label(option).uppercased() : label(option))
                            .font(TypeScale.smallButton)
                            .tracking(classic ? 1.1 : 0)
                    }
                    .foregroundColor(
                        active
                            ? (classic ? Palette.onSecondaryContainer : Palette.onPrimary) : Palette.onSurface
                    )
                    .padding(.horizontal, classic ? 10 : 11)
                    .padding(.vertical, classic ? 4 : 5)
                    .frame(maxWidth: .infinity)
                    .background(
                        active
                            ? (classic ? Palette.secondaryContainer : Palette.primary)
                            : (classic ? Palette.surface : Color.clear)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: classic ? 0 : 5))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(active ? [.isSelected] : [])

                if classic && index < options.count - 1 {
                    Rectangle().fill(Palette.outline).frame(width: Metrics.hairline)
                }
            }
        }
        .padding(classic ? 0 : 3)
        .fixedSize(horizontal: true, vertical: true)
        .background(classic ? Color.clear : Palette.controlBackground)
        .clipShape(RoundedRectangle(cornerRadius: classic ? 0 : Metrics.controlRadius))
        .overlay(
            RoundedRectangle(cornerRadius: classic ? 0 : Metrics.controlRadius).strokeBorder(
                classic ? Palette.outline : .clear, lineWidth: Metrics.hairline))
    }
}

// MARK: - Progress

/// Slim capsule progress track.
struct ProgressBar: View {
    let value: Double  // 0…1
    var height: CGFloat = 6

    var body: some View {
        let radius: CGFloat = InterfaceStyle.current == .classic ? 0 : 100
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: radius).fill(Palette.primaryContainer)
                RoundedRectangle(cornerRadius: radius)
                    .fill(Palette.primary)
                    .frame(width: max(0, min(1, value)) * geo.size.width)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Chip

/// Small pill for counts and job status. Outlined by default; pass `fill` for a solid tone.
struct Chip: View {
    let text: String
    var foreground: Color = Palette.onSurfaceVariant
    var fill: Color? = nil

    var body: some View {
        let radius: CGFloat = InterfaceStyle.current == .classic ? 0 : 100
        Text(InterfaceStyle.current == .classic ? text.uppercased() : text)
            .font(.system(size: 10.5, weight: .medium))
            .foregroundColor(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: radius).fill(fill ?? Color.clear))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(
                        fill == nil ? Palette.outlineVariant : Color.clear,
                        lineWidth: Metrics.hairline)
            )
    }
}

// MARK: - Fields

/// Outlined text field that thickens its edge to the accent while focused.
struct FieldStyle: ViewModifier {
    @FocusState private var focused: Bool

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .focused($focused)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous)
                    .fill(InterfaceStyle.current == .classic ? Palette.surface : Palette.controlBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous)
                    .strokeBorder(
                        focused
                            ? Palette.primary
                            : (InterfaceStyle.current == .classic ? Palette.outline : .clear),
                        lineWidth: focused ? 2 : Metrics.hairline)
            )
            .animation(.easeOut(duration: 0.12), value: focused)
    }
}

// MARK: - Rules and surfaces

/// Full-width hairline separator.
struct HairlineDivider: View {
    var major: Bool = false

    var body: some View {
        Rectangle()
            .fill(
                InterfaceStyle.current == .classic && !major ? Color(hex: 0xC3C2BC) : Palette.outlineVariant
            )
            .frame(height: InterfaceStyle.current == .classic && !major ? 1 : Metrics.hairline)
    }
}

extension View {
    func roundedField() -> some View { modifier(FieldStyle()) }

    /// Hairline pinned to the top edge, separating major regions of the window.
    func topDivider() -> some View {
        overlay(alignment: .top) {
            Rectangle().fill(Palette.outlineVariant).frame(height: Metrics.hairline)
        }
    }

    /// Rounded, hairline-outlined surface for ad-hoc panels that aren't full `Card`s.
    func panel(radius: CGFloat = Metrics.cardRadius, fill: Color = Palette.surface) -> some View {
        background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Palette.outlineVariant, lineWidth: Metrics.hairline)
            )
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    /// Native controls inherit the accent, and toggles read as compact switches.
    @ViewBuilder func materialControls() -> some View {
        if InterfaceStyle.current == .classic {
            tint(Color(nsColor: .systemBlue)).toggleStyle(ClassicCheckboxStyle())
        } else {
            tint(Palette.primary).toggleStyle(CompactSwitchStyle())
        }
    }
}

/// Flat rounded checkbox matching Classic's compact gray controls.
struct ClassicCheckboxStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(configuration.isOn ? Palette.primary : Palette.checkboxBackground)
                    .frame(width: 15, height: 15)
                    .overlay {
                        if configuration.isOn {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Palette.onPrimary)
                        }
                    }
                configuration.label.foregroundColor(Palette.onSurface)
            }
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Toggle(configuration).toggleStyle(.checkbox)
        }
    }
}

/// A switch sized to sit beside a 12.5pt label. The regular macOS switch is tall enough to
/// out-weigh the row it belongs to, and setting `controlSize` globally would shrink the pop-ups
/// and sliders too — wrapping it in a style scopes the size to toggles alone.
struct CompactSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Toggle(configuration)
            .toggleStyle(.switch)
            .controlSize(.small)
    }
}
