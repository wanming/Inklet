import AppKit
import SwiftUI
import InkletCore

@MainActor
private final class SettingsWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
private final class RoundedSettingsHostingView<Content: View>: NSHostingView<Content> {
    private let cornerRadius: CGFloat = 16

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureLayer()
    }

    override func layout() {
        super.layout()
        configureLayer()
    }

    private func configureLayer() {
        wantsLayer = true
        guard let layer else { return }
        layer.backgroundColor = NSColor.clear.cgColor
        layer.cornerRadius = cornerRadius
        layer.cornerCurve = .continuous
        layer.masksToBounds = true
    }
}

@MainActor
final class SettingsWindowController: NSWindowController {
    private let configStore: UserDefaultsConfigStore
    private var appActivationObserver: NSObjectProtocol?
    private var permissionSettingsObserver: NSObjectProtocol?
    private var permissionRestoreTask: Task<Void, Never>?
    private var shouldRestoreAfterPermissionSettings = false
    private var lastShownSection: SettingsSection = .general

    init() {
        self.configStore = UserDefaultsConfigStore()
        let window = SettingsWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 560),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.text("settings.window.title")
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.contentView = RoundedSettingsHostingView(rootView: SettingsView())
        window.isReleasedWhenClosed = false

        super.init(window: window)
        shouldCascadeWindows = false

        permissionSettingsObserver = NotificationCenter.default.addObserver(
            forName: .inkletDidOpenPermissionSettings,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let rawPermission = notification.userInfo?["permission"] as? String
            Task { @MainActor in
                self?.shouldRestoreAfterPermissionSettings = true
                self?.lastShownSection = .permissions
                if let rawPermission,
                    let permission = PermissionSettingsDestination(rawValue: rawPermission) {
                    self?.schedulePermissionRestore(for: permission)
                }
            }
        }

        appActivationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.restoreAfterPermissionSettingsIfNeeded()
            }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(section: SettingsSection = .general) {
        lastShownSection = section
        window?.title = L10n.text("settings.window.title")
        let config = (try? configStore.load()) ?? AppConfig.defaultConfig()
        window?.appearance = config.appearance.nsAppearance
        window?.contentView = RoundedSettingsHostingView(rootView: SettingsView(initialSection: section))
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func restoreAfterPermissionSettingsIfNeeded() {
        guard shouldRestoreAfterPermissionSettings else {
            return
        }

        shouldRestoreAfterPermissionSettings = false
        show(section: lastShownSection)
    }

    private func schedulePermissionRestore(for permission: PermissionSettingsDestination) {
        permissionRestoreTask?.cancel()
        permissionRestoreTask = Task { @MainActor in
            for _ in 0..<60 {
                guard !Task.isCancelled else {
                    return
                }
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else {
                    return
                }
                if permission.isTrusted {
                    shouldRestoreAfterPermissionSettings = false
                    show(section: lastShownSection)
                    return
                }
            }
        }
    }
}

@MainActor
enum PermissionSettingsDestination: String {
    case accessibility
    case inputMonitoring

    var isTrusted: Bool {
        switch self {
        case .accessibility:
            AccessibilityPermissionService().isTrusted
        case .inputMonitoring:
            InputMonitoringPermissionService().isTrusted
        }
    }
}
