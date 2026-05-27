import AppKit
import InkletCore

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
    private let windowController: InkletPopoverWindowController
    private let settingsController: SettingsWindowController
    private let hotkeyManager: GlobalHotkeyManager
    private let configStore: UserDefaultsConfigStore
    private let accessibilityPermissionService: AccessibilityPermissionService
    private let inputMonitoringPermissionService: InputMonitoringPermissionService
    private let voiceStatusController: VoiceStatusWindowController
    private let voiceShortcutMonitor: VoiceShortcutMonitor
    private let audioRecorder: AudioRecorder
    private let insertionService: InsertionService
    private let apiKeyStore: LocalAPIKeyStore
    private var configObserver: NSObjectProtocol?
    private var hotkeyRecordingObserver: NSObjectProtocol?
    private var languageObserver: NSObjectProtocol?
    private var activeApplicationObserver: NSObjectProtocol?
    private var settingsShortcutMonitor: Any?
    private var lastTargetApplication: NSRunningApplication?
    private var didShowInputMonitoringPermissionError = false
    private var isRecordingHotkey = false
    private lazy var voiceCoordinator = makeVoiceInputCoordinator()

    override init() {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.windowController = InkletPopoverWindowController()
        self.settingsController = SettingsWindowController()
        self.hotkeyManager = GlobalHotkeyManager()
        self.configStore = UserDefaultsConfigStore()
        self.accessibilityPermissionService = AccessibilityPermissionService()
        self.inputMonitoringPermissionService = InputMonitoringPermissionService()
        self.voiceStatusController = VoiceStatusWindowController()
        self.voiceShortcutMonitor = VoiceShortcutMonitor()
        self.audioRecorder = AudioRecorder()
        self.insertionService = InsertionService()
        self.apiKeyStore = LocalAPIKeyStore()
        super.init()

        self.windowController.onOpenSettings = { [weak self] in
            self?.openSettings()
        }
        self.voiceStatusController.onCancel = { [weak self] in
            Task { @MainActor in
                await self?.voiceCoordinator.cancel()
            }
        }
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
                self?.rememberTargetApplication(application)
            }
        }

        configObserver = NotificationCenter.default.addObserver(
            forName: .appConfigDidSave,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard self?.isRecordingHotkey == false else {
                    return
                }
                self?.registerConfiguredHotkey()
                self?.configureVoiceInput()
            }
        }

        hotkeyRecordingObserver = NotificationCenter.default.addObserver(
            forName: .hotkeyRecordingDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let isRecording = notification.userInfo?["isRecording"] as? Bool ?? false
            Task { @MainActor in
                self?.setHotkeyRecording(isRecording)
            }
        }

        languageObserver = NotificationCenter.default.addObserver(
            forName: .inkletLanguageDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.configureStatusItemMenu()
            }
        }

        registerConfiguredHotkey()
        configureVoiceInput()
        showPermissionSettingsIfNeeded()
        installSettingsShortcutMonitor()
    }

    func stop() {
        if let configObserver {
            NotificationCenter.default.removeObserver(configObserver)
            self.configObserver = nil
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
        voiceShortcutMonitor.stop()
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        let quitItem = NSMenuItem(
            title: L10n.text("app.menu.quit"),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenu.addItem(quitItem)
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))

        let redoItem = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redoItem)

        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))

        let pasteAndMatchStyleItem = NSMenuItem(
            title: "Paste and Match Style",
            action: #selector(NSTextView.pasteAsPlainText(_:)),
            keyEquivalent: "v"
        )
        pasteAndMatchStyleItem.keyEquivalentModifierMask = [.command, .option, .shift]
        editMenu.addItem(pasteAndMatchStyleItem)

        editMenu.addItem(NSMenuItem(title: "Delete", action: #selector(NSText.delete(_:)), keyEquivalent: ""))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }

    private func installSettingsShortcutMonitor() {
        guard settingsShortcutMonitor == nil else {
            return
        }

        settingsShortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard event.keyCode == 43, modifiers == .command else {
                return event
            }

            Task { @MainActor in
                self?.openSettings()
            }
            return nil
        }
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
        guard !isRecordingHotkey else {
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
                    self?.openPopover()
                }
            }
        } catch {
            NSLog("Failed to register configured hotkey: \(String(describing: error))")
        }
    }

    private func configureVoiceInput() {
        do {
            let config = try configStore.load()
            guard config.voiceInput.shortcut == .disabled || inputMonitoringPermissionService.isTrusted else {
                voiceShortcutMonitor.stop()
                if !didShowInputMonitoringPermissionError {
                    didShowInputMonitoringPermissionError = true
                    voiceStatusController.apply(.error(L10n.text("voice.error.inputMonitoringPermission")))
                }
                return
            }
            didShowInputMonitoringPermissionError = false
            voiceShortcutMonitor.update(shortcut: config.voiceInput.shortcut) { [weak self] in
                Task { @MainActor in
                    await self?.voiceCoordinator.toggle()
                }
            }
        } catch {
            NSLog("Failed to configure voice input: \(String(describing: error))")
        }
    }

    private func makeVoiceInputCoordinator() -> VoiceInputCoordinator {
        VoiceInputCoordinator(
            configProvider: { [weak self] in
                ((try? self?.configStore.load()) ?? AppConfig.defaultConfig()).voiceInput
            },
            targetApplicationProvider: { [weak self] in
                self?.lastTargetApplication
            },
            startRecording: { [weak self] in
                try await self?.audioRecorder.start()
            },
            stopRecording: { [weak self] in
                guard let self else {
                    throw AudioRecorder.AudioRecorderError.recordingUnavailable
                }
                return try await self.audioRecorder.stop()
            },
            cancelRecording: { [weak self] in
                await self?.audioRecorder.cancel()
            },
            transcribe: { [weak self] request in
                guard let self else {
                    throw SpeechTranscriptionError.provider(L10n.text("voice.error.recordingUnavailable"))
                }
                let config = try self.configStore.load()
                guard let endpoint = URL(string: config.voiceInput.speechEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                    throw SpeechTranscriptionError.invalidEndpoint
                }
                defer {
                    try? FileManager.default.removeItem(at: request.audioFileURL)
                }
                let provider = OpenAISpeechTranscriptionProvider(
                    apiKeyProvider: { [apiKeyStore] in
                        guard let apiKey = apiKeyStore.loadAPIKey(forProviderID: VoiceInputConfig.openAISpeechProviderID),
                              !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        else {
                            throw SpeechTranscriptionError.provider(L10n.text("voice.error.missingSpeechAPIKey"))
                        }
                        return apiKey
                    },
                    endpoint: endpoint
                )
                return try await provider.transcribe(request)
            },
            cleanup: { [weak self] source, modeID in
                guard let self else {
                    throw CancellationError()
                }
                let config = try self.configStore.load()
                let providerPreset = config.resolvedProviderPreset
                let providerID = config.providerID
                let apiKeyStore = self.apiKeyStore
                let provider = LLMProviderFactory.provider(for: providerPreset) {
                    guard let apiKey = apiKeyStore.loadAPIKey(forProviderID: providerID),
                          !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    else {
                        throw TransformationError.provider(L10n.format("popover.error.missingAPIKey", providerPreset.name))
                    }
                    return apiKey
                }
                let mode = config.promptModeStore.resolve(modeID: modeID, sourceText: source)
                let result = try await TransformationService(provider: provider).transform(
                    sourceText: source,
                    mode: mode,
                    model: config.model,
                    temperature: config.temperature,
                    timeoutSeconds: config.timeoutSeconds
                )
                return result.outputText
            },
            insert: { [weak self] text, targetApplication in
                guard let self else {
                    throw CancellationError()
                }
                try await self.insertionService.insert(text: text, into: targetApplication)
            },
            statusHandler: { [weak self] status in
                self?.voiceStatusController.apply(status)
            }
        )
    }

    private func setHotkeyRecording(_ isRecording: Bool) {
        guard isRecordingHotkey != isRecording else {
            return
        }

        isRecordingHotkey = isRecording
        if isRecording {
            hotkeyManager.unregister()
        } else {
            registerConfiguredHotkey()
        }
    }

    private func showPermissionSettingsIfNeeded() {
        let config = (try? configStore.load()) ?? AppConfig.defaultConfig()
        let needsAccessibility = !accessibilityPermissionService.isTrusted
        let needsInputMonitoring = config.voiceInput.shortcut != .disabled && !inputMonitoringPermissionService.isTrusted

        guard needsAccessibility || needsInputMonitoring else {
            return
        }

        showSettings(section: .permissions)
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
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()
        defer {
            image.unlockFocus()
            image.isTemplate = true
        }

        NSColor.black.setFill()
        NSBezierPath(roundedRect: NSRect(x: 4.5, y: 13.1, width: 9, height: 1.8), xRadius: 0.9, yRadius: 0.9).fill()
        NSBezierPath(roundedRect: NSRect(x: 8.0, y: 4.0, width: 2, height: 10.4), xRadius: 1.0, yRadius: 1.0).fill()
        NSBezierPath(roundedRect: NSRect(x: 4.2, y: 3.1, width: 9.6, height: 1.8), xRadius: 0.9, yRadius: 0.9).fill()

        return image
    }

    private func configureStatusItemMenu() {
        let menu = NSMenu()
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
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            NSMenuItem(
                title: L10n.text("app.menu.quit"),
                action: #selector(quit),
                keyEquivalent: "q"
            )
        )
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }

    @objc func openPopover() {
        windowController.show(fallbackApplication: lastTargetApplication)
    }

    @objc func openSettings() {
        showSettings(section: .general)
    }

    private func showSettings(section: SettingsSection) {
        windowController.hide()
        settingsController.show(section: section)
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }
}
