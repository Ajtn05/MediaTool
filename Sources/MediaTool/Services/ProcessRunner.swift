import Foundation

/// Async wrapper around `Process` that streams stdout line by line and terminates
/// the child process when the calling task is cancelled.
final class ProcessRunner {

    struct Result {
        let exitCode: Int32
        /// Tail of stderr, useful for surfacing failure messages.
        let stderrTail: String
    }

    /// Launches `executable` with `arguments`. `onProgressLine` receives each line from
    /// stdout (where ffmpeg's `-progress pipe:1` output goes). Returns when the process exits.
    /// Cancelling the surrounding task terminates the child process.
    static func run(
        executable: String,
        arguments: [String],
        onProgressLine: ((String) -> Void)? = nil
    ) async throws -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        // Never let a tool block on stdin (e.g. ffmpeg's overwrite prompt).
        process.standardInput = FileHandle.nullDevice

        // Collect stderr on a background reader so the pipe buffer never fills and deadlocks.
        let stderrBuffer = LineBuffer()
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty { stderrBuffer.appendData(data) }
        }

        // stdout must be drained even when nobody is listening: a tool that fills the 64 KB pipe
        // buffer blocks forever waiting for a reader.
        let stdoutBuffer = LineBuffer()
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            guard let onProgressLine else { return }  // read and discard
            for line in stdoutBuffer.appendAndDrainLines(data) {
                onProgressLine(line)
            }
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Result, Error>) in
                process.terminationHandler = { proc in
                    stdoutPipe.fileHandleForReading.readabilityHandler = nil
                    stderrPipe.fileHandleForReading.readabilityHandler = nil
                    let tail = stderrBuffer.string
                    continuation.resume(
                        returning: Result(
                            exitCode: proc.terminationStatus,
                            stderrTail: tail))
                }
                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            if process.isRunning {
                process.terminate()
            }
        }
    }
}

/// Accumulates bytes and splits them into whole lines. `Process` readability handlers
/// hand us arbitrary chunks; ffmpeg's `-progress` output is newline-delimited.
private final class LineBuffer {
    private var data = Data()
    private let lock = NSLock()
    /// Only the tail of stderr is ever shown, so cap it — a long encode can otherwise emit
    /// megabytes of warnings and we'd hold all of it in memory.
    private static let maxBytes = 16 * 1024

    func appendData(_ new: Data) {
        lock.lock()
        defer { lock.unlock() }
        data.append(new)
        if data.count > Self.maxBytes {
            data.removeFirst(data.count - Self.maxBytes)
        }
    }

    var string: String {
        lock.lock()
        defer { lock.unlock() }
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Appends bytes and returns any newly completed lines, keeping the trailing partial.
    func appendAndDrainLines(_ new: Data) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        data.append(new)
        var lines: [String] = []
        let newline = UInt8(ascii: "\n")
        while let idx = data.firstIndex(of: newline) {
            let lineData = data.subdata(in: data.startIndex..<idx)
            if let line = String(data: lineData, encoding: .utf8) {
                lines.append(line)
            }
            data.removeSubrange(data.startIndex...idx)
        }
        return lines
    }
}
