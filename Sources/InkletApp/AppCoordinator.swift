import AppKit
import InkletCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let coordinator: AppCoordinator
    private var terminationTask: Task<Void, Never>?

    init(
        migrationOutcome: LegacySandboxMigrationOutcome,
        migrator: LegacySandboxDataMigrator,
        storagePaths: InkletStoragePaths
    ) {
        self.coordinator = AppCoordinator(
            migrationOutcome: migrationOutcome,
            migrator: migrator,
            storagePaths: storagePaths
        )
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        coordinator.start()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard terminationTask == nil else {
            return .terminateLater
        }

        terminationTask = Task { @MainActor [coordinator] in
            await coordinator.stop()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}

@MainActor
enum UpdateCheckMenuConfiguration {
    static func apply(to menu: NSMenu) {
        menu.autoenablesItems = false
    }
}

@MainActor
final class AppCoordinator: NSObject, NSMenuDelegate {
    private let migrationOutcome: LegacySandboxMigrationOutcome
    private let migrator: LegacySandboxDataMigrator
    private let storagePaths: InkletStoragePaths
    private let migrationPresentationModel: LegacyMigrationPresentationModel
    private let statusItem: NSStatusItem
    private let windowController: InkletPopoverWindowController
    private let settingsController: SettingsWindowController
    private let aboutController: AboutWindowController
    private let hotkeyManager: GlobalHotkeyManager
    private let configStore: UserDefaultsConfigStore
    private let accessibilityPermissionService: AccessibilityPermissionService
    private let apiKeyStore: LocalAPIKeyStore
    private let selectionActions: SelectionActionsController
    private let historyStore: JSONLHistoryStore
    private var configObserver: NSObjectProtocol?
    private var accessibilityObserver: NSObjectProtocol?
    private var onboardingObserver: NSObjectProtocol?
    private var hotkeyRecordingObserver: NSObjectProtocol?
    private var languageObserver: NSObjectProtocol?
    private var activeApplicationObserver: NSObjectProtocol?
    private var settingsShortcutMonitor: Any?
    private var lastTargetApplication: NSRunningApplication?
    private var isRecordingHotkey = false
    private var isMigrationMaintenanceActive = false
    private var isStopping = false
    private var mainUpdateCheckMenuItem: NSMenuItem?
    private var statusUpdateCheckMenuItem: NSMenuItem?
    private var trackedMenus: Set<ObjectIdentifier> = []
    private lazy var automaticUpdatePresentationGate = AutomaticUpdatePresentationGate(
        canPresent: { [weak self] in
            self?.canPresentAutomaticUpdate ?? false
        },
        present: { [weak self] in
            self?.updateCheckCoordinator.presentPendingAutomaticUpdateIfPossible()
        }
    )
    private lazy var updateCheckAlertPresenter: UpdateCheckAlertPresenter = {
        let presenter = UpdateCheckAlertPresenter()
        presenter.onPresentationStateChange = { [weak self] isPresenting in
            self?.refreshUpdateCheckMenuItems()
            guard !isPresenting else { return }
            Task { @MainActor [weak self] in
                self?.refreshMigrationImportEligibility()
            }
        }
        return presenter
    }()
    private lazy var updateCheckCoordinator = makeUpdateCheckCoordinator()

    init(
        migrationOutcome: LegacySandboxMigrationOutcome,
        migrator: LegacySandboxDataMigrator,
        storagePaths: InkletStoragePaths
    ) {
        SelectionActionDiagnostics.configure(fileURL: storagePaths.selectionDiagnosticsFileURL)
        let historyStore = JSONLHistoryStore(fileURL: storagePaths.historyFileURL)
        let configStore = UserDefaultsConfigStore()
        let apiKeyStore = LocalAPIKeyStore()
        let migrationPresentationModel = LegacyMigrationPresentationModel(outcome: migrationOutcome)
        let accessibilityPermissionService = AccessibilityPermissionService()

        self.migrationOutcome = migrationOutcome
        self.migrator = migrator
        self.storagePaths = storagePaths
        self.migrationPresentationModel = migrationPresentationModel
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.historyStore = historyStore
        self.windowController = InkletPopoverWindowController(
            historyStore: historyStore,
            configStore: configStore,
            apiKeyStore: apiKeyStore
        )
        self.settingsController = SettingsWindowController(
            historyStore: historyStore,
            migrationPresentationModel: migrationPresentationModel
        )
        self.aboutController = AboutWindowController()
        self.hotkeyManager = GlobalHotkeyManager()
        self.configStore = configStore
        self.accessibilityPermissionService = accessibilityPermissionService
        self.apiKeyStore = apiKeyStore
        self.selectionActions = SelectionActionsController(
            configStore: configStore,
            apiKeyStore: apiKeyStore,
            historyStore: historyStore,
            accessibilityPermissionService: accessibilityPermissionService,
            translationCache: JSONSelectionTranslationCache(
                fileURL: storagePaths.translationCacheFileURL
            )
        )
        super.init()

        self.windowController.onOpenSettings = { [weak self] in
            self?.openSettings()
        }
        self.windowController.onBusyChange = { [weak self] _ in
            guard let self, !self.isStopping else { return }
            self.refreshMigrationImportEligibility()
        }
        self.settingsController.onRequestMigrationImport = { [weak self] in
            Task { @MainActor in
                await self?.requestAssistedMigrationImport()
            }
        }
        self.settingsController.onRetryMigrationRelaunch = { [weak self] in
            Task { @MainActor in
                await self?.retryMigrationRelaunch()
            }
        }
        self.settingsController.onQuitForMigration = {
            NSApp.terminate(nil)
        }
        self.settingsController.onMigrationWorkflowIdleChange = { [weak self] _ in
            self?.refreshMigrationImportEligibility()
        }
        self.selectionActions.onWorkStateChange = { [weak self] in
            self?.refreshMigrationImportEligibility()
        }
        self.selectionActions.onInteractionEnded = { [weak self] in
            guard let self, !self.isStopping else { return }
            self.automaticUpdatePresentationGate.schedule()
        }
    }

    private func makeUpdateCheckCoordinator() -> UpdateCheckCoordinator {
        let checker = GitHubReleaseUpdateChecker()
        let currentBuildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let coordinator = UpdateCheckCoordinator(
            automaticChecksEnabled: storagePaths.bundleIdentifier == InkletStoragePaths.productionBundleIdentifier,
            currentVersion: BuildInfo.displayVersion,
            scheduler: FoundationUpdateCheckOneShotScheduler(),
            presenter: updateCheckAlertPresenter,
            check: {
                try await checker.check(currentBuildNumber: currentBuildNumber)
            }
        )
        coordinator.onCheckingStateChange = { [weak self] _ in
            self?.refreshUpdateCheckMenuItems()
        }
        coordinator.onPendingAutomaticUpdate = { [weak self] in
            self?.automaticUpdatePresentationGate.schedule()
        }
        return coordinator
    }

    func start() {
        configureMainMenu()
        configureStatusItemIcon()
        configureStatusItemMenu()

        rememberTargetApplication(NSWorkspace.shared.frontmostApplication)
        activeApplicationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            Task { @MainActor in
                guard let self, !self.isStopping else { return }
                self.handleActivatedApplication(application)
            }
        }

        configObserver = NotificationCenter.default.addObserver(
            forName: .appConfigDidSave,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.isStopping, !self.isRecordingHotkey else {
                    return
                }
                self.registerConfiguredHotkey()
                self.windowController.reloadDictationConfiguration()
                self.selectionActions.configureSelectionActions()
            }
        }

        accessibilityObserver = NotificationCenter.default.addObserver(
            forName: .inkletAccessibilityDidBecomeTrusted,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.isStopping else { return }
                self.selectionActions.configureSelectionActions()
            }
        }

        onboardingObserver = NotificationCenter.default.addObserver(
            forName: .inkletDidCompleteOnboarding,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.isStopping else { return }
                self.openPopover()
            }
        }

        hotkeyRecordingObserver = NotificationCenter.default.addObserver(
            forName: .hotkeyRecordingDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let isRecording = notification.userInfo?["isRecording"] as? Bool ?? false
            Task { @MainActor in
                guard let self, !self.isStopping else { return }
                self.setHotkeyRecording(isRecording)
            }
        }

        languageObserver = NotificationCenter.default.addObserver(
            forName: .inkletLanguageDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.isStopping else { return }
                self.configureMainMenu()
                self.configureStatusItemMenu()
            }
        }

        registerConfiguredHotkey()
        windowController.reloadDictationConfiguration()
        selectionActions.configureSelectionActions()
        showPermissionSettingsIfNeeded()
        installSettingsShortcutMonitor()
        refreshMigrationImportEligibility()
        settingsController.showMigrationNotice()
        updateCheckCoordinator.start()
    }

    func stop() async {
        isStopping = true
        updateCheckCoordinator.stop()
        automaticUpdatePresentationGate.cancel()
        if let configObserver {
            NotificationCenter.default.removeObserver(configObserver)
            self.configObserver = nil
        }
        if let accessibilityObserver {
            NotificationCenter.default.removeObserver(accessibilityObserver)
            self.accessibilityObserver = nil
        }
        if let onboardingObserver {
            NotificationCenter.default.removeObserver(onboardingObserver)
            self.onboardingObserver = nil
        }
        if let hotkeyRecordingObserver {
            NotificationCenter.default.removeObserver(hotkeyRecordingObserver)
            self.hotkeyRecordingObserver = nil
        }
        if let languageObserver {
            NotificationCenter.default.removeObserver(languageObserver)
            self.languageObserver = nil
        }
        if let activeApplicationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activeApplicationObserver)
            self.activeApplicationObserver = nil
        }
        if let settingsShortcutMonitor {
            NSEvent.removeMonitor(settingsShortcutMonitor)
            self.settingsShortcutMonitor = nil
        }
        hotkeyManager.unregister()
        selectionActions.beginStopping()

        await windowController.cancelDictationAndWait()
        await selectionActions.finishStopping()
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        UpdateCheckMenuConfiguration.apply(to: appMenu)
        appMenu.delegate = self
        let aboutItem = NSMenuItem(
            title: L10n.text("app.menu.about"),
            action: #selector(openAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        appMenu.addItem(aboutItem)
        let updateItem = makeCheckForUpdatesMenuItem()
        mainUpdateCheckMenuItem = updateItem
        appMenu.addItem(updateItem)
        appMenu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(
            title: L10n.text("app.menu.quit"),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenu.addItem(quitItem)
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: L10n.text("app.menu.edit"))
        editMenu.delegate = self
        editMenu.addItem(NSMenuItem(title: L10n.text("app.menu.undo"), action: Selector(("undo:")), keyEquivalent: "z"))

        let redoItem = NSMenuItem(title: L10n.text("app.menu.redo"), action: Selector(("redo:")), keyEquivalent: "Z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redoItem)

        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: L10n.text("app.menu.cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: L10n.text("app.menu.copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: L10n.text("app.menu.paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v"))

        let pasteAndMatchStyleItem = NSMenuItem(
            title: L10n.text("app.menu.pasteAndMatchStyle"),
            action: #selector(NSTextView.pasteAsPlainText(_:)),
            keyEquivalent: "v"
        )
        pasteAndMatchStyleItem.keyEquivalentModifierMask = [.command, .option, .shift]
        editMenu.addItem(pasteAndMatchStyleItem)

        editMenu.addItem(NSMenuItem(title: L10n.text("app.menu.delete"), action: #selector(NSText.delete(_:)), keyEquivalent: ""))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: L10n.text("app.menu.selectAll"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
        refreshUpdateCheckMenuItems()
    }

    private func installSettingsShortcutMonitor() {
        guard !isStopping, settingsShortcutMonitor == nil else {
            return
        }

        settingsShortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, !self.isStopping else { return event }
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard event.keyCode == 43, modifiers == .command else {
                return event
            }

            Task { @MainActor in
                guard !self.isStopping else { return }
                self.openSettings()
            }
            return nil
        }
    }

    private var migrationWorkflowsAreIdle: Bool {
        !windowController.isBusy
            && settingsController.isMigrationWorkflowIdle
            && selectionActions.isIdle
    }

    private var canRequestAssistedMigration: Bool {
        !isMigrationMaintenanceActive && migrationWorkflowsAreIdle
    }

    private var canPresentAutomaticUpdate: Bool {
        AutomaticUpdatePresentationState(
            isMigrationMaintenanceActive: isMigrationMaintenanceActive,
            isRecordingHotkey: isRecordingHotkey,
            migrationWorkflowsAreIdle: migrationWorkflowsAreIdle,
            isSelectingMigrationSource: migrationPresentationModel.phase == .selecting,
            hasModalWindow: NSApp.modalWindow != nil,
            isSelectionPanelVisible: selectionActions.isPanelVisible,
            isSelectionInteractionActive: selectionActions.isInteractionActive,
            isMenuTracking: !trackedMenus.isEmpty,
            isUpdateAlertPresenting: updateCheckAlertPresenter.isPresentingAlert,
            isStopping: isStopping
        ).canPresent
    }

    private func refreshMigrationImportEligibility() {
        guard !isStopping else { return }
        migrationPresentationModel.setWorkflowsIdle(
            canRequestAssistedMigration
        )
        automaticUpdatePresentationGate.schedule()
    }

    private func requestAssistedMigrationImport() async {
        guard canRequestAssistedMigration,
              migrationPresentationModel.canRequestImport
        else {
            refreshMigrationImportEligibility()
            return
        }

        migrationPresentationModel.beginSelecting()
        defer { refreshMigrationImportEligibility() }
        let panel = NSOpenPanel()
        panel.title = L10n.text("legacyMigration.panel.title")
        panel.message = L10n.text("legacyMigration.panel.message")
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        guard await panel.begin() == .OK, let selectedURL = panel.url else {
            migrationPresentationModel.cancelSelecting()
            return
        }

        let importOutcome: LegacySandboxMigrationOutcome
        do {
            let isAccessingSecurityScopedResource = selectedURL.startAccessingSecurityScopedResource()
            defer {
                if isAccessingSecurityScopedResource {
                    selectedURL.stopAccessingSecurityScopedResource()
                }
            }

            let validatedDataRoot: URL
            do {
                validatedDataRoot = try migrator.validateUserSelectedDataRoot(selectedURL)
            } catch {
                migrationPresentationModel.failInvalidSelection()
                return
            }

            guard canRequestAssistedMigration else {
                migrationPresentationModel.failImport()
                refreshMigrationImportEligibility()
                return
            }

            guard settingsController.flushPendingEdits() else {
                migrationPresentationModel.failImport()
                refreshMigrationImportEligibility()
                return
            }
            migrationPresentationModel.beginImporting()
            settingsController.setMigrationMaintenanceActive(true)
            await enterMigrationMaintenance()

            let migrator = self.migrator
            importOutcome = await Task.detached(priority: .userInitiated) {
                migrator.migrateUserSelectedData(at: validatedDataRoot)
            }.value
        }

        if importOutcome.changedDestination {
            migrationPresentationModel.beginRelaunching(with: importOutcome)
            await relaunchAfterMigration()
            return
        }

        migrationPresentationModel.update(with: importOutcome)
        leaveMigrationMaintenance()
    }

    private func enterMigrationMaintenance() async {
        isMigrationMaintenanceActive = true
        hotkeyManager.unregister()
        selectionActions.enterMigrationMaintenance()
        await windowController.cancelForMigrationMaintenance()
        await settingsController.waitForMigrationMaintenanceQuiescence()
        refreshMigrationImportEligibility()
    }

    private func leaveMigrationMaintenance() {
        settingsController.setMigrationMaintenanceActive(false)
        isMigrationMaintenanceActive = false
        registerConfiguredHotkey()
        windowController.reloadDictationConfiguration()
        selectionActions.leaveMigrationMaintenance()
        refreshMigrationImportEligibility()
    }

    private func retryMigrationRelaunch() async {
        guard migrationPresentationModel.phase == .relaunchFailed else { return }
        migrationPresentationModel.beginRelaunching(with: migrationPresentationModel.outcome)
        await relaunchAfterMigration()
    }

    private func relaunchAfterMigration() async {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        let didOpen = await withCheckedContinuation { continuation in
            NSWorkspace.shared.openApplication(
                at: Bundle.main.bundleURL,
                configuration: configuration
            ) { application, error in
                continuation.resume(returning: application != nil && error == nil)
            }
        }

        guard didOpen else {
            migrationPresentationModel.markRelaunchFailed()
            return
        }
        NSApp.terminate(nil)
    }

    private func rememberTargetApplication(_ application: NSRunningApplication?) {
        guard let application,
              application.processIdentifier != NSRunningApplication.current.processIdentifier
        else {
            return
        }

        lastTargetApplication = application
    }

    private func handleActivatedApplication(_ application: NSRunningApplication?) {
        guard !isStopping else { return }
        rememberTargetApplication(application)
        selectionActions.handleActivatedApplication(application)
    }

    private func registerConfiguredHotkey() {
        guard !isStopping, !isMigrationMaintenanceActive, !isRecordingHotkey else {
            return
        }

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
                    guard let self, !self.isStopping else { return }
                    self.openPopover()
                }
            }
        } catch {
            NSLog("Failed to register configured hotkey: \(String(describing: error))")
        }
    }

    private func setHotkeyRecording(_ isRecording: Bool) {
        guard !isStopping, isRecordingHotkey != isRecording else {
            return
        }

        isRecordingHotkey = isRecording
        if isRecording {
            hotkeyManager.unregister()
        } else {
            registerConfiguredHotkey()
        }
        refreshMigrationImportEligibility()
    }

    private func showPermissionSettingsIfNeeded() {
        guard !accessibilityPermissionService.isTrusted else {
            return
        }

        showSettings(section: .general)
    }

    private func configureStatusItemIcon() {
        statusItem.length = NSStatusItem.squareLength
        statusItem.button?.attributedTitle = NSAttributedString()
        statusItem.button?.image = makeMenuBarIcon()
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.toolTip = "Inklet"
        statusItem.button?.setAccessibilityLabel("Inklet")
    }

    private func makeMenuBarIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setStroke()
            PenNibGeometry.paths.forEach { geometry in
                guard let firstPoint = geometry.points.first else {
                    return
                }

                let path = NSBezierPath()
                path.lineWidth = 1.5
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                path.move(to: self.menuBarPoint(from: firstPoint))
                geometry.points.dropFirst().forEach { point in
                    path.line(to: self.menuBarPoint(from: point))
                }
                if geometry.isClosed {
                    path.close()
                }
                path.stroke()
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    private func menuBarPoint(from point: PenNibGeometry.Point) -> NSPoint {
        let scale = 0.65
        return NSPoint(
            x: 1.7 + point.x * scale,
            y: 17.3 - point.y * scale
        )
    }

    private func makeCheckForUpdatesMenuItem() -> NSMenuItem {
        let item = NSMenuItem(
            title: "",
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        )
        item.target = self
        return item
    }

    private var isUpdateCheckAvailable: Bool {
        !updateCheckCoordinator.isChecking
            && !updateCheckAlertPresenter.isPresentingAlert
    }

    private func refreshUpdateCheckMenuItems() {
        let isChecking = updateCheckCoordinator.isChecking
        let title = L10n.text(
            isChecking ? "app.menu.checkingForUpdates" : "app.menu.checkForUpdates"
        )
        for item in [mainUpdateCheckMenuItem, statusUpdateCheckMenuItem].compactMap({ $0 }) {
            item.title = title
            item.isEnabled = isUpdateCheckAvailable
        }
    }

    private func configureStatusItemMenu() {
        let menu = NSMenu()
        UpdateCheckMenuConfiguration.apply(to: menu)
        menu.delegate = self
        menu.addItem(
            NSMenuItem(
                title: L10n.text("app.menu.openPopover"),
                action: #selector(openPopover),
                keyEquivalent: ""
            )
        )
        menu.addItem(NSMenuItem.separator())
        let settingsItem = NSMenuItem(
            title: L10n.text("app.menu.settings"),
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.keyEquivalentModifierMask = [.command]
        menu.addItem(settingsItem)
        let updateItem = makeCheckForUpdatesMenuItem()
        statusUpdateCheckMenuItem = updateItem
        menu.addItem(updateItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            NSMenuItem(
                title: L10n.text("app.menu.about"),
                action: #selector(openAbout),
                keyEquivalent: ""
            )
        )
        menu.addItem(
            NSMenuItem(
                title: L10n.text("app.menu.quit"),
                action: #selector(quit),
                keyEquivalent: "q"
            )
        )
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
        refreshUpdateCheckMenuItems()
    }

    func menuWillOpen(_ menu: NSMenu) {
        trackedMenus.insert(ObjectIdentifier(menu))
    }

    func menuDidClose(_ menu: NSMenu) {
        trackedMenus.remove(ObjectIdentifier(menu))
        refreshMigrationImportEligibility()
    }

    @objc func checkForUpdates() {
        guard isUpdateCheckAvailable else {
            refreshUpdateCheckMenuItems()
            return
        }
        updateCheckCoordinator.checkManually()
    }

    @objc func openPopover() {
        guard !isStopping, !isMigrationMaintenanceActive else { return }
        selectionActions.forceDismissSelectionActions(reason: "openPopover")
        windowController.show(fallbackApplication: lastTargetApplication)
    }

    @objc func openSettings() {
        guard !isStopping else { return }
        selectionActions.forceDismissSelectionActions(reason: "openSettings")
        showSettings(section: .general)
    }

    @objc func openAbout() {
        guard !isStopping, !isMigrationMaintenanceActive else { return }
        selectionActions.forceDismissSelectionActions(reason: "openAbout")
        aboutController.show()
    }

    private func showSettings(section: SettingsSection) {
        windowController.hide()
        settingsController.show(section: section)
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }
}
