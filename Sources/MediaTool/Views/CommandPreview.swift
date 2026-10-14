import SwiftUI

/// Shows the exact command that will run for the current settings — transparency + a teaching aid.
struct CommandPreview: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        Card {
            HStack(spacing: 7) {
                Image(systemName: "terminal")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Palette.accentText)
                SectionHeader("Command")
                Spacer()
                Button {
                    copyToPasteboard(app.previewCommand())
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(TypeScale.body)
                        .foregroundColor(Palette.onSurfaceVariant)
                }
                .buttonStyle(.plain)
                .help("Copy command")
            }

            ScrollView(.horizontal, showsIndicators: true) {
                Text(app.previewCommand())
                    .font(TypeScale.mono)
                    .foregroundColor(Palette.onSurface)
                    .textSelection(.enabled)
                    .padding(11)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .panel(radius: Metrics.controlRadius, fill: Palette.surfaceVariant)
        }
    }
}
