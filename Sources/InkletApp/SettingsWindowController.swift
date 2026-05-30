import AppKit
import SwiftUI
import InkletCore

@MainActor
private final class SettingsWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        close()
    }

    override func keyDown(with event: NSEvent) {
        guard event.keyCode == 53 else {
            super.keyDown(with: event)
            return
        }

        close()
    }
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
    private static let didCompleteOnboardingKey = "didCompleteOnboarding"

    private let configStore: UserDefaultsConfigStore
    private let apiKeyStore: LocalAPIKeyStore
    private let userDefaults: UserDefaults
    private var appActivationObserver: NSObjectProtocol?
    private var permissionSettingsObserver: NSObjectProtocol?
    private var settingsWindowCloseObserver: NSObjectProtocol?
    private var systemSettingsDeactivationObserver: NSObjectProtocol?
    private var systemSettingsTerminationObserver: NSObjectProtocol?
    private var permissionRestoreTask: Task<Void, Never>?
    private var didOpenAccessibilitySettings = false
    private var shouldRestoreAfterPermissionSettings = false
    private var lastShownSection: SettingsSection = .general

    init() {
        self.configStore = UserDefaultsConfigStore()
        self.apiKeyStore = LocalAPIKeyStore()
        self.userDefaults = .standard
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
        window.hidesOnDeactivate = false
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
                self?.didOpenAccessibilitySettings = true
                self?.lastShownSection = .permissions
                if let rawPermission,
                    let permission = PermissionSettingsDestination(rawValue: rawPermission) {
                    self?.schedulePermissionRestore(for: permission)
                }
            }
        }

        settingsWindowCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.openPopoverAfterCompletingOnboardingIfNeeded()
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

        let workspaceNotificationCenter = NSWorkspace.shared.notificationCenter
        systemSettingsDeactivationObserver = workspaceNotificationCenter.addObserver(
            forName: NSWorkspace.didDeactivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let bundleIdentifier = application?.bundleIdentifier
            Task { @MainActor in
                self?.restoreAfterSystemSettingsClosedIfNeeded(bundleIdentifier: bundleIdentifier)
            }
        }
        systemSettingsTerminationObserver = workspaceNotificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let bundleIdentifier = application?.bundleIdentifier
            Task { @MainActor in
                self?.restoreAfterSystemSettingsClosedIfNeeded(bundleIdentifier: bundleIdentifier)
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
        notifyAccessibilityTrustIfNeeded()
        show(section: sectionAfterPermissionSettings())
    }

    private func restoreAfterSystemSettingsClosedIfNeeded(bundleIdentifier: String?) {
        guard PermissionSettingsRestorePolicy.shouldRestore(
            afterDeactivatingApplicationWithBundleIdentifier: bundleIdentifier
        ) else {
            return
        }

        restoreAfterPermissionSettingsIfNeeded()
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
                    notifyAccessibilityTrustIfNeeded()
                    show(section: sectionAfterPermissionSettings())
                    return
                }
            }
        }
    }

    private func sectionAfterPermissionSettings() -> SettingsSection {
        let config = (try? configStore.load()) ?? AppConfig.defaultConfig()
        let providerAPIKey = apiKeyStore.loadAPIKey(forProviderID: config.providerID)
        return OnboardingPolicy.needsProviderSetup(providerAPIKey: providerAPIKey) ? .providers : lastShownSection
    }

    private func notifyAccessibilityTrustIfNeeded() {
        guard AccessibilityPermissionService().isTrusted else {
            return
        }

        NotificationCenter.default.post(name: .inkletAccessibilityDidBecomeTrusted, object: nil)
    }

    private func openPopoverAfterCompletingOnboardingIfNeeded() {
        let config = (try? configStore.load()) ?? AppConfig.defaultConfig()
        let providerAPIKey = apiKeyStore.loadAPIKey(forProviderID: config.providerID)
        guard OnboardingPolicy.shouldOpenPopoverAfterClosingSettings(
            didOpenAccessibilitySettings: didOpenAccessibilitySettings,
            isAccessibilityTrusted: AccessibilityPermissionService().isTrusted,
            providerAPIKey: providerAPIKey,
            didCompleteOnboarding: userDefaults.bool(forKey: Self.didCompleteOnboardingKey)
        ) else {
            return
        }

        userDefaults.set(true, forKey: Self.didCompleteOnboardingKey)
        NotificationCenter.default.post(name: .inkletDidCompleteOnboarding, object: nil)
    }
}

@MainActor
enum PermissionSettingsDestination: String {
    case accessibility

    var isTrusted: Bool {
        switch self {
        case .accessibility:
            AccessibilityPermissionService().isTrusted
        }
    }
}
