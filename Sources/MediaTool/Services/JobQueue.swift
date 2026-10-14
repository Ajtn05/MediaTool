import Foundation

/// Runs jobs one at a time, publishing live progress. All state mutation happens on the
/// main actor so SwiftUI observation is safe.
@MainActor
final class JobQueue: ObservableObject {
    @Published private(set) var jobs: [Job] = []
    @Published private(set) var isRunning = false

    private var runTask: Task<Void, Never>?

    // MARK: Queue management

    func add(_ newJobs: [Job]) {
        jobs.append(contentsOf: newJobs)
        startIfIdle()
    }

    func remove(_ job: Job) {
        guard job.state != .running else { return }
        jobs.removeAll { $0.id == job.id }
    }

    func clearFinished() {
        jobs.removeAll { $0.state.isTerminal }
    }

    /// Cancels the whole run; the in-flight process is terminated.
    func cancelAll() {
        runTask?.cancel()
        for job in jobs where job.state == .queued {
            job.state = .cancelled
        }
    }

    // MARK: Aggregate progress

    var overallProgress: Double {
        let active = jobs.filter { !$0.state.isTerminal || $0.state == .completed }
        guard !active.isEmpty else { return 0 }
        let total = active.reduce(0.0) { acc, job in
            acc + (job.state == .completed ? 1.0 : job.progress)
        }
        return total / Double(active.count)
    }

    var queuedCount: Int { jobs.filter { $0.state == .queued }.count }

    // MARK: Execution

    private func startIfIdle() {
        guard !isRunning else { return }
        guard jobs.contains(where: { $0.state == .queued }) else { return }
        isRunning = true
        runTask = Task { [weak self] in
            await self?.processAll()
            guard let self else { return }
            self.isRunning = false
            self.reportDrained()
        }
    }

    private func processAll() async {
        while let job = jobs.first(where: { $0.state == .queued }) {
            if Task.isCancelled { break }
            await run(job)
            publishProgress()
        }
    }

    // MARK: System feedback

    /// Pushes live progress to the Dock while jobs run.
    private func publishProgress() {
        let remaining = jobs.filter { !$0.state.isTerminal }.count
        lastDockPercent = Int(overallProgress * 100)
        DockProgress.update(progress: overallProgress, remaining: remaining)
    }

    private var lastDockPercent = -1

    /// Redraws the Dock tile only when the whole-percent value actually changes —
    /// ffmpeg emits progress lines many times a second.
    fileprivate func publishProgressThrottled() {
        let percent = Int(overallProgress * 100)
        guard percent != lastDockPercent else { return }
        publishProgress()
    }

    /// Called once when the queue empties: clear the Dock and notify.
    private func reportDrained() {
        DockProgress.clear()

        var completed = 0
        var failed = 0
        var cancelled = 0
        for job in jobs {
            switch job.state {
            case .completed: completed += 1
            case .failed: failed += 1
            case .cancelled: cancelled += 1
            default: break
            }
        }
        Notifier.queueFinished(completed: completed, failed: failed, cancelled: cancelled)
    }

    /// The job currently being converted, for the menu bar readout.
    var currentJob: Job? { jobs.first { $0.state == .running } }

    private func run(_ job: Job) async {
        job.state = .running
        job.progress = 0

        guard let executable = job.command.first else {
            job.state = .failed("No tool configured")
            return
        }
        let baseArgs = Array(job.command.dropFirst())

        // ffmpeg jobs (video/audio) stream progress; image jobs run opaquely.
        let isFFmpeg = job.kind == .video || job.kind == .audio
        let runtimeArgs: [String]
        let parser = ProgressParser(totalSeconds: job.durationSeconds)
        if isFFmpeg {
            runtimeArgs = ["-nostats", "-progress", "pipe:1"] + baseArgs
        } else {
            runtimeArgs = baseArgs
        }

        do {
            let result = try await ProcessRunner.run(
                executable: executable,
                arguments: runtimeArgs,
                onProgressLine: isFFmpeg
                    ? { [weak job, weak self] line in
                        guard let job else { return }
                        if let f = parser.fraction(from: line) {
                            DispatchQueue.main.async {
                                job.progress = f
                                self?.publishProgressThrottled()
                            }
                        }
                    } : nil
            )

            if result.exitCode == 0 {
                job.progress = 1
                job.state = .completed
            } else {
                job.state = .failed(Self.friendlyError(from: result.stderrTail))
            }
        } catch is CancellationError {
            job.state = .cancelled
        } catch {
            job.state = .failed(error.localizedDescription)
        }
    }

    /// Extracts the most useful line from a tool's stderr for display.
    private static func friendlyError(from stderr: String) -> String {
        let lines =
            stderr
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return lines.last ?? "Conversion failed"
    }
}
