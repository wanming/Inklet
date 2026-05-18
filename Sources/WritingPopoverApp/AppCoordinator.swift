import AppKit
import WritingPopoverCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let coordinator = AppCoordinator()

    func applicationDidFinishLaunching(_ notification: Notification) {
        coordinator.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator.stop()
    }
}

@MainActor
final class AppCoordinator: NSObject {
    private let statusItem: NSStatusItem
    private let windowController: WritingPopoverWindowController
    private let settingsController: SettingsWindowController
    private let hotkeyManager: GlobalHotkeyManager

    override init() {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.windowController = WritingPopoverWindowController()
        self.settingsController = SettingsWindowController()
        self.hotkeyManager = GlobalHotkeyManager()
        super.init()
    }

    func start() {
        statusItem.button?.title = "AI"

        let menu = NSMenu()
        menu.addItem(
            NSMenuItem(
                title: "打开写作浮窗",
                action: #selector(openPopover),
                keyEquivalent: ""
            )
        )
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            NSMenuItem(
                title: "设置",
                action: #selector(openSettings),
                keyEquivalent: ","
            )
        )
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            NSMenuItem(
                title: "退出",
                action: #selector(quit),
                keyEquivalent: "q"
            )
        )
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu

        do {
            try hotkeyManager.register(Hotkey(keyCode: 49, modifiers: [.option])) { [weak self] in
                Task { @MainActor in
                    self?.openPopover()
                }
            }
        } catch {
            NSLog("Failed to register default hotkey: \(String(describing: error))")
        }
    }

    func stop() {
        hotkeyManager.unregister()
    }

    @objc func openPopover() {
        windowController.show()
    }

    @objc func openSettings() {
        settingsController.show()
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }
}
