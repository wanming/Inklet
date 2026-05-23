import AppKit
import SwiftUI
import InkletCore

@MainActor
private final class SettingsWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class SettingsWindowController: NSWindowController {
    private let configStore: UserDefaultsConfigStore

    init() {
        self.configStore = UserDefaultsConfigStore()
        let hostingController = NSHostingController(rootView: SettingsView())
        let window = SettingsWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 560),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.text("settings.window.title")
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false

        super.init(window: window)
        shouldCascadeWindows = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        window?.title = L10n.text("settings.window.title")
        let config = (try? configStore.load()) ?? AppConfig.defaultConfig()
        window?.appearance = config.appearance.nsAppearance
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
