import SwiftUI

/// Utility-style navigation, file workspace, and settings inspector for the default theme.
struct ModernWorkspace<Settings: View>: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var tools: ToolLocator
    @EnvironmentObject var queue: JobQueue
    @ViewBuilder let settings: () -> Settings
    @State private var sidebarVisible = true

    var body: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width >= 900
            let split = geometry.size.width >= 700

            HStack(spacing: 0) {
                if wide && sidebarVisible {
                    sidebar
                        .frame(width: 180)
                    verticalDivider
                }
                VStack(spacing: 0) {
                    toolbar(showSidebarToggle: wide)
                    let missing = app.activeMissingTools()
                    if !missing.isEmpty {
                        MissingToolBanner(packages: missing) { tools.refresh() }
                    }
                    if split {
                        HSplitView {
                            filesPane
                                .frame(minWidth: 220, idealWidth: 330)
                            inspector
                                .frame(minWidth: 430, idealWidth: 470)
                        }
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {
                                DropZone()
                                notice
                                if !app.stagedURLs.isEmpty {
                                    StagedList().frame(minHeight: 80, maxHeight: 200)
                                }
                                settings()
                                CommandPreview()
                            }
                            .padding(20)
                        }
                        OutputBar(compact: true).topDivider()
                    }
                    if !queue.jobs.isEmpty {
                        QueueView()
                            .frame(minHeight: 100, maxHeight: split ? 180 : 130)
                            .topDivider()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Palette.background)
            .materialControls()
            .background(WindowChrome(accessory: Wordmark(), height: 36).frame(width: 0, height: 0))
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 22) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    sidebarGroup("Video") {
                        navigationRow(
                            "Convert", symbol: "film", selected: app.mode == .video && app.videoOp == .convert
                        ) {
                            app.mode = .video
                            app.videoOp = .convert
                        }
                        navigationRow(
                            "Extract frames", symbol: "photo.stack",
                            selected: app.mode == .video && app.videoOp == .extractFrames
                        ) {
                            app.mode = .video
                            app.videoOp = .extractFrames
                        }
                        navigationRow(
                            "Join clips", symbol: "rectangle.stack",
                            selected: app.mode == .video && app.videoOp == .join
                        ) {
                            app.mode = .video
                            app.videoOp = .join
                        }
                    }
                    sidebarGroup("Audio") {
                        navigationRow("Convert", symbol: "waveform", selected: app.mode == .audio) {
                            app.mode = .audio
                        }
                    }
                    sidebarGroup("Images") {
                        navigationRow(
                            "Convert", symbol: "photo",
                            selected: app.mode == .image && app.imageOp == .convert
                        ) {
                            app.mode = .image
                            app.imageOp = .convert
                        }
                        navigationRow(
                            "Contact sheet", symbol: "square.grid.3x3",
                            selected: app.mode == .image && app.imageOp == .contactSheet
                        ) {
                            app.mode = .image
                            app.imageOp = .contactSheet
                        }
                        navigationRow(
                            "Export sizes", symbol: "square.resize",
                            selected: app.mode == .image && app.imageOp == .multiSize
                        ) {
                            app.mode = .image
                            app.imageOp = .multiSize
                        }
                    }
                }
                .padding(.top, 18)
            }
            HStack(spacing: 6) {
                Image(systemName: queue.isRunning ? "arrow.triangle.2.circlepath" : "checkmark.circle")
                Text(queue.isRunning ? "Converting…" : "Ready")
            }
            .font(TypeScale.caption)
            .foregroundColor(Palette.onSurfaceVariant)
            .padding(.horizontal, 10)
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 10)
        .background(.regularMaterial)
    }

    private func sidebarGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content)
        -> some View
    {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Palette.onSurfaceVariant)
                .padding(.horizontal, 10)
                .padding(.bottom, 5)
            content()
        }
    }

    private func navigationRow(_ title: String, symbol: String, selected: Bool, action: @escaping () -> Void)
        -> some View
    {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Palette.primary)
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 13, weight: selected ? .semibold : .regular))
                    .foregroundColor(Palette.onSurface)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                selected ? Palette.selection : .clear,
                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private func toolbar(showSidebarToggle: Bool) -> some View {
        HStack(spacing: 12) {
            if showSidebarToggle {
                Button {
                    sidebarVisible.toggle()
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 15))
                        .foregroundColor(Palette.onSurfaceVariant)
                        .frame(width: 30, height: 30)
                        .background(Palette.controlBackground, in: Circle())
                }
                .buttonStyle(.plain)
                .help("Show or hide sidebar")
            }
            Menu {
                Section("Video") {
                    ForEach(VideoOperation.allCases) { operation in
                        Button(operation.rawValue) {
                            app.mode = .video
                            app.videoOp = operation
                        }
                    }
                }
                Section("Audio") {
                    Button("Convert audio") { app.mode = .audio }
                }
                Section("Images") {
                    ForEach(ImageOperation.allCases) { operation in
                        Button(operation.rawValue) {
                            app.mode = .image
                            app.imageOp = operation
                        }
                    }
                }
            } label: {
                Text(operationTitle).font(TypeScale.title).foregroundColor(Palette.onSurface)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            Spacer(minLength: 12)
            PresetBar().fixedSize()
        }
        .padding(.horizontal, 20)
        .frame(height: 52)
        .background(Palette.background)
        .overlay(alignment: .bottom) { HairlineDivider() }
    }

    private var operationTitle: String {
        switch app.mode {
        case .video:
            switch app.videoOp {
            case .convert: return "Convert video"
            case .extractFrames: return "Extract frames"
            case .join: return "Join clips"
            }
        case .audio: return "Convert audio"
        case .image:
            switch app.imageOp {
            case .convert: return "Convert images"
            case .contactSheet: return "Contact sheet"
            case .multiSize: return "Export sizes"
            }
        }
    }

    private var filesPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            notice
            if app.stagedURLs.isEmpty {
                Spacer(minLength: 0)
                DropZone(spacious: true)
                    .frame(maxWidth: 330)
                    .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
            } else {
                DropZone()
                StagedList()
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.workspace)
    }

    private var inspector: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    settings()
                    CommandPreview()
                }
                .padding(20)
            }
            OutputBar(compact: true).topDivider()
        }
        .background(Palette.background)
    }

    @ViewBuilder private var notice: some View {
        if let notice = app.notice {
            Text(notice)
                .font(TypeScale.caption)
                .foregroundColor(Palette.onSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Palette.primaryContainer, in: RoundedRectangle(cornerRadius: Metrics.controlRadius))
        }
    }

    private var verticalDivider: some View {
        Rectangle().fill(Palette.outlineVariant).frame(width: Metrics.hairline)
    }
}
