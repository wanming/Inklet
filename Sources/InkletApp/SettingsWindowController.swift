import AppKit
import Combine
import SwiftUI
import InkletCore

/// A native titled window with a transparent titlebar: the system draws the traffic lights,
/// rounded corners and shadow, and the titlebar strip drags the window.
@MainActor
private final class SettingsWindow: NSWindow {
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
final class SettingsWindowController: NSWindowController {
    private static let systemSettingsBundleIdentifier = "com.apple.systempreferences"

    private let configStore: UserDefaultsConfigStore
    private let apiKeyStore: LocalAPIKeyStore
    private let userDefaults: UserDefaults
    private let historyStore: any HistoryStore
    private let model: SettingsViewModel
    private let migrationPresentationModel: LegacyMigrationPresentationModel
    private var permissionSettingsObserver: NSObjectProtocol?
    private var settingsWindowCloseObserver: NSObjectProtocol?
    private var permissionMonitorTask: Task<Void, Never>?
    private var systemSettingsReturnTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var didOpenAccessibilitySettings = false

    var onRequestMigrationImport: (() -> Void)?
    var onRetryMigrationRelaunch: (() -> Void)?
    var onQuitForMigration: (() -> Void)?
    var onMigrationWorkflowIdleChange: ((Bool) -> Void)?

    var isMigrationWorkflowIdle: Bool {
        model.isMigrationWorkflowIdle
    }

    /// The welcome guide edits the same settings, so the Settings window never saves a stale copy.
    var settingsModel: SettingsViewModel {
        model
    }

    init(
        historyStore: any HistoryStore = JSONLHistoryStore(),
        migrationPresentationModel: LegacyMigrationPresentationModel
    ) {
        self.configStore = UserDefaultsConfigStore()
        self.apiKeyStore = LocalAPIKeyStore()
        self.userDefaults = .standard
        self.historyStore = historyStore
        self.model = SettingsViewModel(historyStore: historyStore)
        self.migrationPresentationModel = migrationPresentationModel
        let window = SettingsWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.text("settings.window.title")
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.hidesOnDeactivate = false
        window.contentView = NSHostingView(rootView: EmptyView())
        window.isReleasedWhenClosed = false

        super.init(window: window)
        shouldCascadeWindows = false

        NotificationCenter.default.publisher(for: .inkletLanguageDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak window] _ in
                window?.title = L10n.text("settings.window.title")
            }
            .store(in: &cancellables)

        model.$isMigrationWorkflowIdle
            .removeDuplicates()
            .sink { [weak self] isIdle in
                self?.onMigrationWorkflowIdleChange?(isIdle)
            }
            .store(in: &cancellables)

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
        window?.contentView = NSHostingView(
            rootView: SettingsView(
                model: model,
                migrationPresentationModel: migrationPresentationModel,
                initialSection: section,
                onAppearanceChange: { [weak window] appearance in
                    window?.appearance = appearance.nsAppearance
                },
                onRequestMigrationImport: { [weak self] in
                    self?.onRequestMigrationImport?()
                },
                onRetryMigrationRelaunch: { [weak self] in
                    self?.onRetryMigrationRelaunch?()
                },
                onQuitForMigration: { [weak self] in
                    self?.onQuitForMigration?()
                }
            )
        )
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func flushPendingEdits() -> Bool {
        model.flushPendingEdits()
    }

    func setMigrationMaintenanceActive(_ isActive: Bool) {
        model.setMigrationMaintenanceActive(isActive)
    }

    func waitForMigrationMaintenanceQuiescence() async {
        await model.waitForMigrationMaintenanceQuiescence()
    }

    func showMigrationNotice() {
        guard migrationPresentationModel.phase != .hidden else { return }
        show(section: .general)
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

        let providerAPIKey = apiKeyStore.loadAPIKey(forProviderID: configuredProviderID)
        guard !OnboardingPolicy.shouldShowProviderSetupAfterReturningFromPermissionSettings(
            providerAPIKey: providerAPIKey,
            requiresAPIKey: configuredProviderRequiresAPIKey
        ) else {
            show(section: .general)
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private var configuredProviderID: String {
        ((try? configStore.load()) ?? AppConfig.defaultConfig()).providerID
    }

    private var configuredProviderRequiresAPIKey: Bool {
        ((try? configStore.load()) ?? AppConfig.defaultConfig()).resolvedProviderPreset.requiresAPIKey
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
        let providerAPIKey = apiKeyStore.loadAPIKey(forProviderID: configuredProviderID)
        guard OnboardingPolicy.shouldOpenPopoverAfterClosingSettings(
            didOpenAccessibilitySettings: didOpenAccessibilitySettings,
            isAccessibilityTrusted: AccessibilityPermissionService().isTrusted,
            providerAPIKey: providerAPIKey,
            requiresAPIKey: configuredProviderRequiresAPIKey,
            didCompleteOnboarding: userDefaults.bool(forKey: InkletPreferenceKeys.didCompleteOnboarding)
        ) else {
            return
        }

        userDefaults.set(true, forKey: InkletPreferenceKeys.didCompleteOnboarding)
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
