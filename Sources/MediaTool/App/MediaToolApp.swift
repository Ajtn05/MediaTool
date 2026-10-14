import SwiftUI

@main
struct MediaToolApp: App {
    @StateObject private var tools: ToolLocator
    @StateObject private var queue: JobQueue
    @StateObject private var appState: AppState
    @StateObject private var presets = PresetStore()
    @StateObject private var theme = ThemeStore()

    @AppStorage("mediatool.appearance") private var appearanceRaw = Appearance.system.rawValue

    private var appearance: Appearance {
        Appearance(rawValue: appearanceRaw) ?? .system
    }

    init() {
        let tools = ToolLocator()
        let queue = JobQueue()
        _tools = StateObject(wrappedValue: tools)
        _queue = StateObject(wrappedValue: queue)
        _appState = StateObject(wrappedValue: AppState(tools: tools, queue: queue))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(tools)
                .environmentObject(queue)
                .environmentObject(presets)
                .environmentObject(theme)
                .frame(minWidth: 460, minHeight: 420)
                .appAppearance(theme.style == .classic ? .light : appearance.colorScheme)
                .task { Notifier.requestAuthorizationIfNeeded() }
        }
        .defaultSize(width: 980, height: 760)
        .windowResizability(.contentMinSize)
        // Drop the title bar and let our own header run to the top edge; the traffic lights
        // stay and float over the canvas (ContentView reserves room for them).
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}  // no "New Window"
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
                .environmentObject(tools)
                .environmentObject(theme)
                .appAppearance(theme.style == .classic ? .light : appearance.colorScheme)
        }

        MenuBarExtra {
            MenuBarView()
                .environmentObject(queue)
                .environmentObject(theme)
                .appAppearance(theme.style == .classic ? .light : appearance.colorScheme)
        } label: {
            MenuBarLogoMark(isRunning: queue.isRunning)
        }
        .menuBarExtraStyle(.window)
    }
}
