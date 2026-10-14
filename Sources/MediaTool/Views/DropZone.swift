import SwiftUI
import UniformTypeIdentifiers

/// Drag-and-drop target plus an "Add Files…" button. Adds valid files to the staging list.
struct DropZone: View {
    @EnvironmentObject var app: AppState
    var spacious: Bool = false
    @State private var isTargeted = false
    @State private var showImporter = false

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: InterfaceStyle.current == .classic ? "arrow.down.doc.fill" : "arrow.down.doc")
                .font(
                    .system(
                        size: InterfaceStyle.current == .classic ? 22 : (spacious ? 38 : 24),
                        weight: InterfaceStyle.current == .classic ? .regular : .light)
                )
                .foregroundColor(isTargeted ? Palette.accentText : Palette.onSurfaceVariant)
            Text(
                InterfaceStyle.current == .classic
                    ? "DROP \(app.mode.rawValue.uppercased()) FILES"
                    : "Drop \(app.mode.rawValue.lowercased()) files here"
            )
            .font(InterfaceStyle.current == .classic ? TypeScale.sectionTitle : TypeScale.body)
            .tracking(InterfaceStyle.current == .classic ? 2 : 0)
            .foregroundColor(isTargeted ? Palette.onPrimaryContainer : Palette.onSurfaceVariant)
            Button(InterfaceStyle.current == .classic ? "ADD FILES…" : "Add Files…") { showImporter = true }
                .buttonStyle(TonalButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .frame(height: InterfaceStyle.current == .classic ? 122 : (spacious ? 246 : 132))
        .background(
            RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                .fill(
                    isTargeted ? Palette.primaryContainer : (spacious ? Color.clear : Palette.surfaceVariant))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                .strokeBorder(
                    isTargeted ? Palette.primary : Palette.outlineVariant,
                    style: StrokeStyle(
                        lineWidth: Metrics.hairline,
                        dash: InterfaceStyle.current == .classic ? [10, 7] : [6, 4]))
        )
        .animation(.easeOut(duration: 0.12), value: isTargeted)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
            return true
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.movie, .video, .audio, .image],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                app.stage(urls)
            }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        let group = DispatchGroup()
        var urls: [URL] = []
        let lock = NSLock()
        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url {
                    lock.lock()
                    urls.append(url)
                    lock.unlock()
                }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            app.stage(urls)
        }
    }
}

/// The list of files staged for conversion, with per-row remove.
struct StagedList: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                SectionHeader("Files")
                if !app.stagedURLs.isEmpty {
                    Chip(
                        text: "\(app.stagedURLs.count)",
                        foreground: Palette.onSecondaryContainer,
                        fill: Palette.secondaryContainer)
                }
                Spacer()
                if !app.stagedURLs.isEmpty {
                    Button("Clear") { app.clearStaged() }
                        .buttonStyle(TextButtonStyle())
                }
            }

            if app.stagedURLs.isEmpty {
                Text("No files added yet.")
                    .font(TypeScale.body)
                    .foregroundColor(Palette.onSurfaceVariant)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(app.stagedURLs.enumerated()), id: \.element) { index, url in
                            StagedRow(url: url, index: index)
                            if index < app.stagedURLs.count - 1 {
                                Rectangle().fill(Palette.outlineVariant).frame(height: Metrics.hairline)
                            }
                        }
                    }
                }
                .panel()
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StagedRow: View {
    @EnvironmentObject var app: AppState
    let url: URL
    let index: Int

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Order matters for join / PDF / contact sheet, so show the position.
            Text("\(index + 1)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(Palette.onSurfaceVariant)
                .frame(width: 16, alignment: .trailing)
                .padding(.top, 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(url.displayName)
                    .font(TypeScale.bodyEmphasis)
                    .foregroundColor(Palette.onSurface)
                    .lineLimit(1)
                    .truncationMode(.middle)
                infoSubtitle
            }

            Spacer(minLength: 4)

            Button {
                app.unstage(url)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Palette.onSurfaceVariant)
            }
            .buttonStyle(.plain)
            .help("Remove")
            .padding(.top, 2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    /// Metadata line: source info + (when known) an estimated output size.
    @ViewBuilder private var infoSubtitle: some View {
        if let info = app.probeInfo[url], !info.summary.isEmpty {
            HStack(spacing: 4) {
                Text(info.summary)
                if let est = app.estimatedOutputBytes(for: url) {
                    Text("→ ~\(ProbeDisplay.formatBytes(est))")
                        .foregroundColor(Palette.accentText)
                }
            }
            .font(TypeScale.monoSmall)
            .foregroundColor(Palette.onSurfaceVariant)
            .lineLimit(1)
            .truncationMode(.middle)
        } else {
            Text("reading…")
                .font(TypeScale.monoSmall)
                .foregroundColor(Palette.onSurfaceVariant)
        }
    }
}
