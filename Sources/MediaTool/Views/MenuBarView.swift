import SwiftUI

/// Menu bar popover: live queue progress so conversions can be watched from other apps.
struct MenuBarView: View {
    @EnvironmentObject var queue: JobQueue
    /// See ContentView: observing the store is what re-renders accent-coloured chrome.
    @EnvironmentObject var theme: ThemeStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                LogoMark(size: 20)
                Text("Media Tool")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Palette.onSurface)
                Spacer()
            }

            if queue.isRunning {
                if let job = queue.currentJob {
                    Text(job.title)
                        .font(TypeScale.body)
                        .foregroundColor(Palette.onSurface)
                        .lineLimit(1).truncationMode(.middle)
                }
                ProgressBar(value: queue.overallProgress)
                    .frame(width: 220)
                HStack {
                    Text("\(Int(queue.overallProgress * 100))% · \(queue.queuedCount) waiting")
                        .font(TypeScale.monoSmall)
                        .foregroundColor(Palette.onSurfaceVariant)
                    Spacer()
                }
            } else {
                Text(summary)
                    .font(TypeScale.caption)
                    .foregroundColor(Palette.onSurfaceVariant)
            }

            HairlineDivider()

            HStack(spacing: 8) {
                if queue.isRunning {
                    Button("Cancel all") { queue.cancelAll() }
                        .buttonStyle(TonalButtonStyle(destructive: true))
                }
                Button("Open") {
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(TonalButtonStyle())
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(TonalButtonStyle())
            }
        }
        .padding(16)
        .frame(width: 264)
        .background(Palette.background)
        .materialControls()
        .id(theme.identity)
    }

    private var summary: String {
        let done = queue.jobs.filter { $0.state == .completed }.count
        if queue.jobs.isEmpty { return "Idle — no jobs queued." }
        let failed = queue.jobs.filter { if case .failed = $0.state { return true } else { return false } }
            .count
        return failed > 0 ? "\(done) done · \(failed) failed" : "\(done) done"
    }
}
