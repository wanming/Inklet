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
    private static let systemSettingsBundleIdentifier = "com.apple.systempreferences"

    private let configStore: UserDefaultsConfigStore
    private let apiKeyStore: LocalAPIKeyStore
    private let userDefaults: UserDefaults
    private var permissionSettingsObserver: NSObjectProtocol?
    private var settingsWindowCloseObserver: NSObjectProtocol?
    private var permissionMonitorTask: Task<Void, Never>?
    private var systemSettingsReturnTask: Task<Void, Never>?
    private var didOpenAccessibilitySettings = false

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
        window.contentView = RoundedSettingsHostingView(rootView: EmptyView())
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
                self?.didOpenAccessibilitySettings = true
                self?.scheduleSystemSettingsReturn()
                if let rawPermission,
                    let permission = PermissionSettingsDestination(rawValue: rawPermission) {
                    self?.schedulePermissionMonitor(for: permission)
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

    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(section: SettingsSection = .general) {
        window?.title = L10n.text("settings.window.title")
        let config = (try? configStore.load()) ?? AppConfig.defaultConfig()
        window?.appearance = config.appearance.nsAppearance
        window?.contentView = RoundedSettingsHostingView(
            rootView: SettingsView(initialSection: section) { [weak window] appearance in
                window?.appearance = appearance.nsAppearance
            }
        )
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func scheduleSystemSettingsReturn() {
        systemSettingsReturnTask?.cancel()
        systemSettingsReturnTask = Task { @MainActor [weak self] in
            var didObserveSystemSettingsRunning = false
            while !Task.isCancelled {
                let isSystemSettingsRunning = !NSRunningApplication.runningApplications(
                    withBundleIdentifier: Self.systemSettingsBundleIdentifier
                ).isEmpty
                if PermissionSettingsRestorePolicy.shouldRefreshAccessibilityServicesAfterRestore(
                    didObserveSystemSettingsRunning: didObserveSystemSettingsRunning,
                    isSystemSettingsRunning: isSystemSettingsRunning,
                    isAccessibilityTrusted: AccessibilityPermissionService().isTrusted
                ) {
                    self?.restoreAfterPermissionSettings()
                    self?.notifyAccessibilityTrustIfNeeded()
                    return
                }
                if PermissionSettingsRestorePolicy.shouldRestore(
                    didObserveSystemSettingsRunning: didObserveSystemSettingsRunning,
                    isSystemSettingsRunning: isSystemSettingsRunning
                ) {
                    self?.restoreAfterPermissionSettings()
                    return
                }
                didObserveSystemSettingsRunning = didObserveSystemSettingsRunning || isSystemSettingsRunning
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    private func restoreAfterPermissionSettings() {
        guard window?.isVisible == true else {
            return
        }

        let providerAPIKey = apiKeyStore.loadAPIKey(forProviderID: LLMProviderPreset.openAI.id)
        guard !OnboardingPolicy.shouldShowProviderSetupAfterReturningFromPermissionSettings(
            providerAPIKey: providerAPIKey
        ) else {
            show(section: .general)
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func schedulePermissionMonitor(for permission: PermissionSettingsDestination) {
        permissionMonitorTask?.cancel()
        permissionMonitorTask = Task { @MainActor in
            for _ in 0..<60 {
                guard !Task.isCancelled else {
                    return
                }
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else {
                    return
                }
                if permission.isTrusted {
                    notifyAccessibilityTrustIfNeeded()
                    return
                }
            }
        }
    }

    private func notifyAccessibilityTrustIfNeeded() {
        guard AccessibilityPermissionService().isTrusted else {
            return
        }

        NotificationCenter.default.post(name: .inkletAccessibilityDidBecomeTrusted, object: nil)
    }

    private func openPopoverAfterCompletingOnboardingIfNeeded() {
        let providerAPIKey = apiKeyStore.loadAPIKey(forProviderID: LLMProviderPreset.openAI.id)
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
