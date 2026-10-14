import SwiftUI

/// The conversion queue with per-item progress, overall progress, and controls.
struct QueueView: View {
    @EnvironmentObject var queue: JobQueue

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                SectionHeader("Queue")
                if queue.queuedCount > 0 {
                    Chip(text: "\(queue.queuedCount) waiting")
                }
                Spacer()
                if queue.isRunning {
                    ProgressBar(value: queue.overallProgress)
                        .frame(width: 130)
                    Button("Cancel all") { queue.cancelAll() }
                        .buttonStyle(TonalButtonStyle(destructive: true))
                }
                Button("Clear finished") { queue.clearFinished() }
                    .buttonStyle(TextButtonStyle())
                    .disabled(!queue.jobs.contains { $0.state.isTerminal })
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.vertical, 10)

            HairlineDivider()

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(queue.jobs) { job in
                        JobRow(job: job)
                        HairlineDivider()
                    }
                }
            }
        }
        .background(Palette.background)
    }
}

struct JobRow: View {
    @ObservedObject var job: Job
    @EnvironmentObject var queue: JobQueue

    var body: some View {
        HStack(spacing: 10) {
            statusIcon.frame(width: 18)

            VStack(alignment: .leading, spacing: 4) {
                Text(job.title)
                    .font(TypeScale.bodyEmphasis)
                    .foregroundColor(Palette.onSurface)
                    .lineLimit(1).truncationMode(.middle)
                subtitle
            }

            Spacer()

            trailingControl
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.vertical, 9)
    }

    @ViewBuilder private var statusIcon: some View {
        switch job.state {
        case .queued:
            Image(systemName: "clock")
                .font(TypeScale.body)
                .foregroundColor(Palette.onSurfaceVariant)
        case .running:
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Palette.accentText)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13))
                .foregroundColor(Palette.accentText)
        case .cancelled:
            Image(systemName: "minus.circle")
                .font(TypeScale.body)
                .foregroundColor(Palette.onSurfaceVariant)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 13))
                .foregroundColor(Palette.error)
        }
    }

    @ViewBuilder private var subtitle: some View {
        switch job.state {
        case .queued:
            caption("Waiting")
        case .running:
            if job.durationSeconds != nil {
                ProgressBar(value: job.progress)
                    .frame(maxWidth: 250)
            } else {
                caption("Working…")
            }
        case .completed:
            caption("Done")
        case .cancelled:
            caption("Cancelled")
        case .failed(let message):
            Text(message)
                .font(TypeScale.monoSmall)
                .foregroundColor(Palette.error)
                .lineLimit(2).truncationMode(.tail)
                .help(message)
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(TypeScale.caption)
            .foregroundColor(Palette.onSurfaceVariant)
    }

    @ViewBuilder private var trailingControl: some View {
        switch job.state {
        case .completed:
            Button {
                revealInFinder(job.revealURL)
            } label: {
                Image(systemName: "folder")
                    .font(TypeScale.body)
                    .foregroundColor(Palette.onSurfaceVariant)
            }
            .buttonStyle(.plain)
            .help(job.outputsMultipleFiles ? "Reveal folder in Finder" : "Reveal in Finder")
        case .queued:
            Button {
                queue.remove(job)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Palette.onSurfaceVariant)
            }
            .buttonStyle(.plain)
            .help("Remove from queue")
        default:
            EmptyView()
        }
    }
}
