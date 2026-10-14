import SwiftUI

/// Bottom bar: output destination, name suffix, and the Convert action.
struct OutputBar: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var tools: ToolLocator
    @EnvironmentObject var queue: JobQueue

    /// When narrow, the fields stack above the button instead of sitting beside it.
    var compact: Bool = false

    var body: some View {
        Group {
            if compact {
                VStack(alignment: .leading, spacing: 10) {
                    destinationRow
                    namingRow
                    convertButton.frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        destinationRow
                        namingRow
                    }
                    Spacer()
                    convertButton
                }
            }
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.vertical, compact ? 10 : (InterfaceStyle.current == .classic ? 12 : 14))
        .background(Palette.background)
    }

    private var destinationRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 3) {
                Text(InterfaceStyle.current == .classic ? "SAVE TO" : "Save to")
                    .font(TypeScale.label)
                    .tracking(InterfaceStyle.current == .classic ? 1 : 0)
                    .foregroundColor(Palette.onSurfaceVariant)
                InfoButton(text: HelpText.destination)
            }
            .frame(width: InterfaceStyle.current == .classic ? 88 : 68, alignment: .leading)
            UtilityPicker(
                options: OutputDestination.allCases, selection: $app.destination, label: { $0.rawValue }
            )
            .frame(maxWidth: 190, alignment: .leading)
            .onChange(of: app.destination) { dest in
                if dest == .customFolder {
                    if let folder = chooseFolder() {
                        app.customFolder = folder
                    } else {
                        app.destination = .sameAsSource
                    }
                }
            }
            if app.destination == .customFolder, let folder = app.customFolder {
                Text(folder.displayName)
                    .font(TypeScale.monoSmall)
                    .foregroundColor(Palette.onSurfaceVariant)
                    .lineLimit(1).truncationMode(.middle)
            }
        }
    }

    private var namingRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 3) {
                Text(InterfaceStyle.current == .classic ? "NAME" : "Name")
                    .font(TypeScale.label)
                    .tracking(InterfaceStyle.current == .classic ? 1 : 0)
                    .foregroundColor(Palette.onSurfaceVariant)
                InfoButton(text: HelpText.naming)
            }
            .frame(width: InterfaceStyle.current == .classic ? 88 : 68, alignment: .leading)
            SegmentedControl(
                options: NamingMode.allCases,
                selection: $app.naming,
                label: { $0 == .suffix ? "Suffix" : "Rename" })
            if app.naming == .suffix {
                TextField("-converted", text: $app.nameSuffix)
                    .font(TypeScale.mono)
                    .roundedField()
                    .frame(maxWidth: 130)
                    .disabled(app.combinesAllInputs)
                    .opacity(app.combinesAllInputs ? 0.45 : 1)
            } else {
                TextField("output", text: $app.customName)
                    .font(TypeScale.mono)
                    .roundedField()
                    .frame(maxWidth: 130)
            }
        }
    }

    private var convertLabel: String {
        let n = app.stagedURLs.count
        switch app.mode {
        case .video where app.videoOp == .join:
            return n > 0 ? "Join \(n) clips" : "Join clips"
        case .video where app.videoOp == .extractFrames:
            return n > 0 ? "Extract from \(n)" : "Extract frames"
        case .image where app.imageOp == .contactSheet:
            return n > 0 ? "Sheet from \(n)" : "Build sheet"
        case .image where app.imageOp == .multiSize:
            return "Export \(app.multiSize.sizes.count) sizes"
        default:
            if app.isCombiningPDF {
                return n > 0 ? "Combine \(n) → PDF" : "Combine → PDF"
            }
            return "Convert \(n > 0 ? "\(n) " : "")file\(n == 1 ? "" : "s")"
        }
    }

    private var convertButton: some View {
        let missing = app.activeMissingTools()
        let needsSizes = app.mode == .image && app.imageOp == .multiSize && app.multiSize.sizes.isEmpty
        let canConvert = !app.stagedURLs.isEmpty && missing.isEmpty && !needsSizes

        return VStack(alignment: .trailing, spacing: 6) {
            Button {
                Task { await app.convertStaged() }
            } label: {
                Label(
                    InterfaceStyle.current == .classic ? convertLabel.uppercased() : convertLabel,
                    systemImage: "play.fill"
                )
                .tracking(InterfaceStyle.current == .classic ? 1.2 : 0)
                .frame(minWidth: 140)
            }
            .buttonStyle(FilledButtonStyle())
            .disabled(!canConvert)
            .opacity(InterfaceStyle.current == .classic && !canConvert ? 0.4 : 1)
            .keyboardShortcut(.return, modifiers: [.command])

            if queue.isRunning {
                Text("Converting…")
                    .font(TypeScale.caption)
                    .foregroundColor(Palette.onSurfaceVariant)
            } else if needsSizes {
                Text("Select a size")
                    .font(TypeScale.caption)
                    .foregroundColor(Palette.onSurfaceVariant)
            }
        }
    }
}
