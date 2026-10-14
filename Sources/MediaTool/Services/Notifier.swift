import AppKit
import UserNotifications

/// Posts a system notification when the queue finishes. Ad-hoc-signed apps can be denied
/// notification authorization, so this always falls back to bouncing the Dock icon — the user
/// gets *some* signal either way.
@MainActor
enum Notifier {
    private static var authorizationRequested = false
    private static var authorized = false

    /// Asks once, early, so the prompt doesn't appear in the middle of a conversion.
    static func requestAuthorizationIfNeeded() {
        guard !authorizationRequested else { return }
        authorizationRequested = true

        // UNUserNotificationCenter traps if the app has no bundle identifier (e.g. `swift run`).
        guard Bundle.main.bundleIdentifier != nil else { return }

        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { granted, _ in
                Task { @MainActor in authorized = granted }
            }
    }

    static func queueFinished(completed: Int, failed: Int, cancelled: Int) {
        let title: String
        if failed > 0 {
            title = "Finished with \(failed) failure\(failed == 1 ? "" : "s")"
        } else if completed > 0 {
            title = "Conversion complete"
        } else {
            title = "Queue finished"
        }

        var parts: [String] = []
        if completed > 0 { parts.append("\(completed) done") }
        if failed > 0 { parts.append("\(failed) failed") }
        if cancelled > 0 { parts.append("\(cancelled) cancelled") }
        let body = parts.joined(separator: " · ")

        post(title: title, body: body)
    }

    private static func post(title: String, body: String) {
        guard authorized, Bundle.main.bundleIdentifier != nil else {
            bounceDock()
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if error != nil {
                Task { @MainActor in bounceDock() }
            }
        }
    }

    /// Fallback signal when notifications aren't available: bounce the Dock icon,
    /// but only if the app isn't already frontmost.
    private static func bounceDock() {
        guard !NSApp.isActive else { return }
        NSApp.requestUserAttention(.informationalRequest)
    }
}
