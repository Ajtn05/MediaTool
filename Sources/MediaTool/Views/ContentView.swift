import SwiftUI

struct ContentView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var tools: ToolLocator
    @EnvironmentObject var queue: JobQueue
    /// Observed so the whole tree re-renders when the accent changes — `Palette.primary` is a
    /// plain static lookup and can't invalidate views on its own.
    @EnvironmentObject var theme: ThemeStore

    /// Below this width the side-by-side split can't hold both columns legibly, so the
    /// files pane and the settings pane stack into a single scrolling column instead.
    private static let stackThreshold: CGFloat = 720

    var body: some View {
        Group {
            if theme.style == .modern {
                ModernWorkspace { settingsBody }
            } else {
                classicLayout
            }
        }
        .id(theme.identity)
    }

    private var classicLayout: some View {
        GeometryReader { geo in
            let stacked = geo.size.width < Self.stackThreshold

            VStack(spacing: 0) {
                modeTabs
                    .padding(.top, InterfaceStyle.current == .classic ? 6 : 8)

                let missing = app.activeMissingTools()
                if !missing.isEmpty {
                    MissingToolBanner(packages: missing) { tools.refresh() }
                }

                if stacked {
                    stackedBody
                } else {
                    HSplitView {
                        inputColumn
                            .frame(minWidth: 280, idealWidth: 330, maxWidth: 460)
                        settingsColumn
                            .frame(minWidth: 430)
                    }
                }

                OutputBar(compact: stacked)
                    .topDivider()

                if !queue.jobs.isEmpty {
                    QueueView()
                        .frame(minHeight: 110, maxHeight: stacked ? 150 : 230)
                        .topDivider()
                }
            }
            .background(Palette.background)
            .materialControls()
            // Zero-size installer: puts the wordmark in the title bar beside the traffic lights
            // and matches the window background to the canvas.
            .background(WindowChrome(accessory: Wordmark()).frame(width: 0, height: 0))
        }
    }

    /// Narrow layout: everything in one scroll view, files first.
    private var stackedBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: InterfaceStyle.current == .classic ? 14 : 16) {
                DropZone()
                if let notice = app.notice {
                    noticeBanner(notice)
                }
                StagedList()
                    .frame(maxHeight: 200)
                HairlineDivider()
                PresetBar()
                OperationPicker()
                settingsBody
                CommandPreview()
            }
            .padding(Metrics.gutter)
        }
        .background(Palette.background)
    }

    // MARK: Mode tabs

    private func noticeBanner(_ notice: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .font(TypeScale.body)
                .foregroundColor(Palette.accentText)
            Text(notice)
                .font(TypeScale.body)
                .foregroundColor(Palette.onPrimaryContainer)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous)
                .fill(Palette.primaryContainer)
        )
    }

    /// Mode tabs sit on their own full-width row, starting at the same gutter as all
    /// content below — so the selector is anchored to the layout grid.
    private var modeTabs: some View {
        VStack(spacing: 0) {
            HStack(spacing: InterfaceStyle.current == .classic ? 12 : 2) {
                ForEach(MediaKind.allCases) { kind in
                    ModeTab(kind: kind, isActive: app.mode == kind) {
                        app.mode = kind
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Metrics.gutter)
            HairlineDivider(major: true)
        }
    }

    // MARK: Columns

    private var inputColumn: some View {
        VStack(alignment: .leading, spacing: InterfaceStyle.current == .classic ? 10 : 12) {
            DropZone()
            if let notice = app.notice {
                noticeBanner(notice)
            }
            StagedList()
        }
        .padding(Metrics.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Palette.background)
    }

    private var settingsColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: InterfaceStyle.current == .classic ? 14 : 16) {
                PresetBar()
                OperationPicker()
                settingsBody
                CommandPreview()
            }
            .padding(Metrics.gutter)
        }
        .background(Palette.background)
    }

    @ViewBuilder private var settingsBody: some View {
        switch app.mode {
        case .video:
            switch app.videoOp {
            case .convert: VideoSettingsView()
            case .extractFrames: FrameExtractView()
            case .join: JoinView()
            }
        case .audio:
            AudioSettingsView()
        case .image:
            switch app.imageOp {
            case .convert: ImageSettingsView()
            case .contactSheet: ContactSheetView()
            case .multiSize: MultiSizeView()
            }
        }
    }
}

// MARK: - Mode tab

struct ModeTab: View {
    let kind: MediaKind
    let isActive: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            if InterfaceStyle.current == .classic {
                HStack(spacing: 8) {
                    Image(systemName: kind.symbol)
                        .font(.system(size: 12, weight: .heavy))
                    Text(kind.rawValue.uppercased())
                        .font(TypeScale.title)
                        .tracking(2)
                }
                .foregroundColor(isActive ? Palette.onPrimary : Palette.onSurfaceVariant)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .frame(minWidth: 94)
                .background(isActive ? Palette.primary : Color.clear)
                .overlay(
                    Rectangle().strokeBorder(
                        isActive ? Palette.outline : Color.clear, lineWidth: Metrics.hairline)
                )
                .contentShape(Rectangle())
            } else {
                VStack(spacing: 6) {
                    HStack(spacing: 7) {
                        Image(systemName: kind.symbol)
                            .font(.system(size: 13, weight: .medium))
                        Text(kind.rawValue)
                            .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                    }
                    .foregroundColor(isActive ? Palette.primary : Palette.onSurfaceVariant)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(hovering && !isActive ? Palette.secondaryContainer.opacity(0.6) : .clear)
                    )

                    // The active tab is marked by a short bar that lands on the rule below the row.
                    Capsule(style: .continuous)
                        .fill(isActive ? Palette.primary : Color.clear)
                        .frame(height: 3)
                        .padding(.horizontal, 8)
                }
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isActive)
    }
}

// MARK: - Operation picker (only shown when a mode has more than one operation)

struct OperationPicker: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        switch app.mode {
        case .video:
            HStack(spacing: 8) {
                SegmentedControl(
                    options: VideoOperation.allCases,
                    selection: $app.videoOp,
                    label: { $0.rawValue },
                    symbol: { $0.symbol })
                InfoButton(text: HelpText.videoOperation)
                Spacer()
            }
        case .image:
            HStack(spacing: 8) {
                SegmentedControl(
                    options: ImageOperation.allCases,
                    selection: $app.imageOp,
                    label: { $0.rawValue },
                    symbol: { $0.symbol })
                InfoButton(text: HelpText.imageOperation)
                Spacer()
            }
        case .audio:
            EmptyView()
        }
    }
}

// MARK: - Missing tool banner

struct MissingToolBanner: View {
    let packages: [String]
    let onRecheck: () -> Void

    var body: some View {
        let installCmd = "brew install " + packages.joined(separator: " ")
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13))
                .foregroundColor(Palette.error)
            VStack(alignment: .leading, spacing: 7) {
                Text("Missing tool: \(packages.joined(separator: ", "))")
                    .font(TypeScale.bodyEmphasis)
                    .foregroundColor(Palette.onSurface)
                HStack(spacing: 8) {
                    Text(installCmd)
                        .font(TypeScale.mono)
                        .foregroundColor(Palette.onSurface)
                        .textSelection(.enabled)
                        .padding(.vertical, 4).padding(.horizontal, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Palette.surface)
                        )
                    Button {
                        copyToPasteboard(installCmd)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(TypeScale.caption)
                            .foregroundColor(Palette.onSurfaceVariant)
                    }
                    .buttonStyle(.plain)
                    .help("Copy command")
                }
            }
            Spacer()
            Button("Re-check", action: onRecheck)
                .buttonStyle(TonalButtonStyle())
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.vertical, 12)
        .background(Palette.error.opacity(0.10))
        .overlay(alignment: .bottom) { HairlineDivider() }
    }
}
