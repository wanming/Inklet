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
    private let configStore: UserDefaultsConfigStore
    private let accessibilityPermissionService: AccessibilityPermissionService
    private var configObserver: NSObjectProtocol?
    private var activeApplicationObserver: NSObjectProtocol?
    private var lastTargetApplication: NSRunningApplication?
    private var didRequestAccessibilityPermissionThisLaunch = false

    override init() {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.windowController = WritingPopoverWindowController()
        self.settingsController = SettingsWindowController()
        self.hotkeyManager = GlobalHotkeyManager()
        self.configStore = UserDefaultsConfigStore()
        self.accessibilityPermissionService = AccessibilityPermissionService()
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

        rememberTargetApplication(NSWorkspace.shared.frontmostApplication)
        activeApplicationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            Task { @MainActor in
                self?.rememberTargetApplication(application)
            }
        }

        configObserver = NotificationCenter.default.addObserver(
            forName: .appConfigDidSave,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.registerConfiguredHotkey()
            }
        }

        registerConfiguredHotkey()
        requestAccessibilityPermissionIfNeeded()
    }

    func stop() {
        if let configObserver {
            NotificationCenter.default.removeObserver(configObserver)
            self.configObserver = nil
        }
        if let activeApplicationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activeApplicationObserver)
            self.activeApplicationObserver = nil
        }
        hotkeyManager.unregister()
    }

    private func rememberTargetApplication(_ application: NSRunningApplication?) {
        guard let application,
              application.processIdentifier != NSRunningApplication.current.processIdentifier
        else {
            return
        }

        lastTargetApplication = application
    }

    private func registerConfiguredHotkey() {
        do {
            let config = try configStore.load()
            let hotkey: Hotkey
            do {
                hotkey = try Hotkey.parse(config.hotkey)
            } catch {
                NSLog("Unsupported configured hotkey, falling back to Option+Space: \(String(describing: error))")
                hotkey = Hotkey(keyCode: 49, modifiers: [.option])
            }

            try hotkeyManager.register(hotkey) { [weak self] in
                Task { @MainActor in
                    self?.openPopover()
                }
            }
        } catch {
            NSLog("Failed to register configured hotkey: \(String(describing: error))")
        }
    }

    private func requestAccessibilityPermissionIfNeeded() {
        guard !didRequestAccessibilityPermissionThisLaunch else {
            return
        }

        didRequestAccessibilityPermissionThisLaunch = true
        accessibilityPermissionService.requestIfNeeded()
    }

    @objc func openPopover() {
        requestAccessibilityPermissionIfNeeded()
        windowController.show(fallbackApplication: lastTargetApplication)
    }

    @objc func openSettings() {
        settingsController.show()
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }
}
