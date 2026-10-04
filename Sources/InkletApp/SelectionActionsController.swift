import AppKit
import InkletCore

@MainActor
private enum SelectionPronunciationReturnState: Equatable {
    case menu
    case translationResult
}

private struct PendingSelectionRead {
    let sourceProcessIdentifier: pid_t
    let location: SelectionPoint
}

private struct PendingUserCopyRead {
    let sourceProcessIdentifier: pid_t
    let location: SelectionPoint
    let clipboardHandoff: SelectionClipboardUserCopyHandoff
}

@MainActor
final class SelectionActionsController {
    var onWorkStateChange: (() -> Void)?
    var onInteractionEnded: (() -> Void)?

    private let configStore: UserDefaultsConfigStore
    private let apiKeyStore: LocalAPIKeyStore
    private let historyStore: JSONLHistoryStore
    private let accessibilityPermissionService: AccessibilityPermissionService
    private let selectionActionMonitor: SelectionActionMonitor
    private let selectionActionWindowController: SelectionActionWindowController
    private let selectionSourceValidator: SelectionSourceValidator
    private let selectionClipboardReader: SelectionClipboardReader
    private let selectionUserCopyReader: SelectionUserCopyReader
    private let selectionReadPipeline: SelectionReadPipeline
    private let selectionTranslationCache: JSONSelectionTranslationCache
    private let speechPlaybackService: SpeechPlaybackService
    private var selectionActionCoordinator: SelectionActionCoordinator
    private let selectionTaskRegistry = SelectionTaskRegistry()
    private var stoppedSelectionTasks: SelectionShutdownTaskSnapshot?
    private var selectionReadTask: Task<Void, Never>?
    private var selectionTranslationTask: Task<Void, Never>?
    private var selectionTTSTask: Task<Void, Never>?
    private var selectionCopyFeedbackTask: Task<Void, Never>?
    private var selectionReadTaskID: UUID?
    private var selectionTranslationTaskID: UUID?
    private var selectionTTSTaskID: UUID?
    private var selectionCopyFeedbackTaskID: UUID?
    private var isSelectionSpeechPlaying = false
    private var isMigrationMaintenanceActive = false
    private var isStopping = false
    private var currentSelectionText = ""
    private var currentTranslationText = ""
    private var selectionPronunciationReturnState = SelectionPronunciationReturnState.menu
    private var panelDismissalPolicy = SelectionPanelDismissalPolicy()

    init(
        configStore: UserDefaultsConfigStore,
        apiKeyStore: LocalAPIKeyStore,
        historyStore: JSONLHistoryStore,
        accessibilityPermissionService: AccessibilityPermissionService,
        translationCache: JSONSelectionTranslationCache
    ) {
        let selectionSourceValidator = SelectionSourceValidator()
        let sourceValidator: SelectionReadPipeline.SourceValidator = {
            selectionSourceValidator.isCurrent($0)
        }
        let selectedTextReader = SelectedTextReader()
        let selectionClipboardReader = SelectionClipboardReader(
            sourceProcessValidator: sourceValidator
        )
        let selectionUserCopyReader = SelectionUserCopyReader(
            sourceProcessValidator: sourceValidator
        )

        self.configStore = configStore
        self.apiKeyStore = apiKeyStore
        self.historyStore = historyStore
        self.accessibilityPermissionService = accessibilityPermissionService
        self.selectionActionMonitor = SelectionActionMonitor()
        self.selectionActionWindowController = SelectionActionWindowController()
        self.selectionSourceValidator = selectionSourceValidator
        self.selectionClipboardReader = selectionClipboardReader
        self.selectionUserCopyReader = selectionUserCopyReader
        self.selectionReadPipeline = SelectionReadPipeline(
            sourceValidator: sourceValidator,
            accessibilityReader: { sourceProcessIdentifier, mouseLocation in
                selectedTextReader.readSelectedText(
                    sourceProcessIdentifier: sourceProcessIdentifier,
                    mouseLocation: mouseLocation
                )
            },
            clipboardReader: { sourceProcessIdentifier, forceSelectionMode in
                await selectionClipboardReader.readSelectedText(
                    sourceProcessIdentifier: sourceProcessIdentifier,
                    forceSelectionMode: forceSelectionMode
                )
            }
        )
        self.selectionTranslationCache = translationCache
        self.speechPlaybackService = SpeechPlaybackService()
        self.selectionActionCoordinator = SelectionActionCoordinator(
            config: ((try? configStore.load()) ?? AppConfig.defaultConfig()).selectionActions
        )

        self.selectionActionMonitor.onCandidateSelection = { [weak self] point in
            guard let self, !self.isStopping else { return }
            self.handleSelectionActionCandidate(at: point)
        }
        self.selectionActionMonitor.onCopyTrigger = { [weak self] trigger in
            guard let self,
                  !self.isStopping,
                  !isMigrationMaintenanceActive,
                  trigger.sourceProcessIdentifier > 0,
                  trigger.sourceProcessIdentifier != NSRunningApplication.current.processIdentifier,
                  selectionSourceValidator.isCurrent(trigger.sourceProcessIdentifier)
            else {
                return
            }
            let clipboardHandoff = selectionClipboardReader.beginUserCopyHandoff()
            let pendingUserCopyRead = PendingUserCopyRead(
                sourceProcessIdentifier: trigger.sourceProcessIdentifier,
                location: trigger.point,
                clipboardHandoff: clipboardHandoff
            )
            self.handleSelectionActionCopyTrigger(pendingUserCopyRead)
        }
        self.selectionActionMonitor.onDismiss = { [weak self] reason in
            guard let self, !self.isStopping else { return }
            self.handleSelectionDismissRequest(
                reason: String(describing: reason),
                bypassingPanelGrace: reason.bypassesPanelGrace
            )
        }
        self.selectionActionMonitor.onInteractionStateChange = { [weak self] isActive in
            guard let self, !self.isStopping, !isActive else { return }
            self.onInteractionEnded?()
        }
        self.selectionActionWindowController.onTranslate = { [weak self] in
            Task { @MainActor in
                self?.translateCurrentSelection()
            }
        }
        self.selectionActionWindowController.onPronounce = { [weak self] in
            Task { @MainActor in
                self?.pronounceCurrentSelection()
            }
        }
        self.selectionActionWindowController.onPronounceOriginal = { [weak self] in
            Task { @MainActor in
                self?.pronounceOriginalFromTranslation()
            }
        }
        self.selectionActionWindowController.onPronounceTranslation = { [weak self] in
            Task { @MainActor in
                self?.pronounceCurrentTranslation()
            }
        }
        self.selectionActionWindowController.onCopyTranslation = { [weak self] in
            self?.copyCurrentTranslation()
        }
        self.selectionActionWindowController.onRetryTranslation = { [weak self] in
            Task { @MainActor in
                self?.translateCurrentSelection()
            }
        }
        self.selectionActionWindowController.onDismiss = { [weak self] in
            guard let self, !self.isStopping else { return }
            self.forceDismissSelectionActions(reason: "selectionPanelEscape")
        }
        self.speechPlaybackService.onFinish = { [weak self] in
            guard let self, !self.isStopping else { return }
            self.isSelectionSpeechPlaying = false
            self.restoreSelectionPronunciationReturnState()
            self.notifyWorkStateChange()
        }
    }

    /// True when no selection read, translation, or pronunciation is running.
    var isIdle: Bool {
        selectionReadTask == nil
            && selectionTranslationTask == nil
            && selectionTTSTask == nil
            && !isSelectionSpeechPlaying
    }

    var isPanelVisible: Bool {
        selectionActionWindowController.isPanelVisible
    }

    var isInteractionActive: Bool {
        selectionActionMonitor.isInteractionActive
    }

    /// Stops new selection work and cancels running tasks without suspending.
    func beginStopping() {
        isStopping = true
        selectionActionMonitor.stop()
        let selectionTasks = selectionTaskRegistry.snapshotAndClear()
        stoppedSelectionTasks = selectionTasks
        selectionReadTask = nil
        selectionTranslationTask = nil
        selectionTTSTask = nil
        selectionCopyFeedbackTask = nil
        selectionReadTaskID = nil
        selectionTranslationTaskID = nil
        selectionTTSTaskID = nil
        selectionCopyFeedbackTaskID = nil
        selectionTasks.cancel()
        speechPlaybackService.stop()
        isSelectionSpeechPlaying = false
    }

    /// Joins the clipboard read and the tasks captured by `beginStopping()`.
    func finishStopping() async {
        await selectionClipboardReader.cancelActiveRead()
        await stoppedSelectionTasks?.waitForCompletion()
        stoppedSelectionTasks = nil
    }

    func enterMigrationMaintenance() {
        isMigrationMaintenanceActive = true
        selectionActionMonitor.stop()
        selectionReadTask?.cancel()
        selectionReadTask = nil
        selectionReadTaskID = nil
        selectionTranslationTask?.cancel()
        selectionTranslationTask = nil
        selectionTranslationTaskID = nil
        selectionTTSTask?.cancel()
        selectionTTSTask = nil
        selectionTTSTaskID = nil
        selectionCopyFeedbackTask?.cancel()
        selectionCopyFeedbackTask = nil
        selectionCopyFeedbackTaskID = nil
        forceDismissSelectionActions(reason: "migrationMaintenance")
        selectionActionWindowController.hidePanel()
        speechPlaybackService.stop()
        isSelectionSpeechPlaying = false
    }

    func leaveMigrationMaintenance() {
        isMigrationMaintenanceActive = false
        configureSelectionActions()
    }

    func handleActivatedApplication(_ application: NSRunningApplication?) {
        guard !isStopping else { return }
        if SelectionActivationDismissalPolicy.shouldDismiss(
            activatedProcessIdentifier: application?.processIdentifier,
            currentProcessIdentifier: NSRunningApplication.current.processIdentifier
        ) {
            SelectionActionDiagnostics.log(
                "activated external app dismiss pid=\(application?.processIdentifier ?? -1)"
            )
            handleSelectionDismissRequest(reason: "externalActivation", bypassingPanelGrace: true)
        } else {
            SelectionActionDiagnostics.log("activated current app ignored for selection dismiss")
        }
    }

    private func notifyWorkStateChange() {
        onWorkStateChange?()
    }

    func configureSelectionActions() {
        guard !isStopping, !isMigrationMaintenanceActive else {
            selectionActionMonitor.stop()
            return
        }
        let config = (try? configStore.load()) ?? AppConfig.defaultConfig()
        handleSelectionActionEffects(selectionActionCoordinator.handle(.updateConfig(config.selectionActions)))
        let isAccessibilityTrusted = accessibilityPermissionService.isTrusted
        SelectionActionDiagnostics.log(
            "configure enabled=\(config.selectionActions.isEnabled) accessibilityTrusted=\(isAccessibilityTrusted)"
        )
        if config.selectionActions.isEnabled, isAccessibilityTrusted {
            if !selectionActionMonitor.start() {
                SelectionActionDiagnostics.log("selection action monitor installation unavailable")
            }
        } else {
            selectionActionMonitor.stop()
        }
    }

    private func handleSelectionActionCandidate(at point: SelectionPoint) {
        guard !isStopping, !isMigrationMaintenanceActive else { return }
        guard let sourceApp = NSWorkspace.shared.frontmostApplication,
              sourceApp.processIdentifier != NSRunningApplication.current.processIdentifier
        else {
            return
        }

        let bundleID = sourceApp.bundleIdentifier ?? "pid-\(sourceApp.processIdentifier)"
        let request = PendingSelectionRead(
            sourceProcessIdentifier: sourceApp.processIdentifier,
            location: point
        )
        SelectionActionDiagnostics.logRateLimited("candidate sourceApp=\(bundleID)")
        handleSelectionActionEffects(selectionActionCoordinator.handle(
            .candidateSelection(sourceAppBundleID: bundleID, mouseLocation: point)
        ), pendingSelectionRead: request)
    }

    private func handleSelectionActionCopyTrigger(_ pendingUserCopyRead: PendingUserCopyRead) {
        guard !isStopping, !isMigrationMaintenanceActive else { return }

        handleSelectionActionEffects(selectionActionCoordinator.handle(.dismiss))
        let taskID = UUID()
        selectionReadTaskID = taskID
        let task = Task { [weak self] in
            guard let self else { return }
            defer {
                self.selectionTaskRegistry.remove(id: taskID)
                if self.selectionReadTaskID == taskID {
                    self.selectionReadTask = nil
                    self.selectionReadTaskID = nil
                    self.notifyWorkStateChange()
                }
            }
            let handoffOutcome = await selectionClipboardReader.finishUserCopyHandoff(
                pendingUserCopyRead.clipboardHandoff
            )
            guard !Task.isCancelled,
                  !isStopping,
                  !isMigrationMaintenanceActive,
                  selectionReadTaskID == taskID
            else {
                return
            }
            switch handoffOutcome {
            case .unobservedSyntheticAction:
                SelectionActionDiagnostics.log("copy trigger ignored unobserved synthetic action")
                return
            case .noActiveRead, .restorationRelinquished, .completedWithoutPasteboardMutation:
                break
            }
            let result = await selectionUserCopyReader.readCopiedText(
                sourceProcessIdentifier: pendingUserCopyRead.sourceProcessIdentifier,
                after: pendingUserCopyRead.clipboardHandoff.boundaryChangeCount
            )
            guard !Task.isCancelled,
                  !isStopping,
                  !isMigrationMaintenanceActive,
                  selectionReadTaskID == taskID,
                  selectionSourceValidator.isCurrent(pendingUserCopyRead.sourceProcessIdentifier)
            else {
                return
            }
            guard case .success(let text) = result, !text.isEmpty else {
                SelectionActionDiagnostics.log("copy trigger empty clipboard")
                return
            }

            SelectionActionDiagnostics.log("copy trigger showPanel length=\(text.count)")
            panelDismissalPolicy.recordPanelShown(at: Date().timeIntervalSinceReferenceDate)
            selectionActionMonitor.recordPanelShown()
            currentSelectionText = text
            currentTranslationText = ""
            selectionPronunciationReturnState = .menu
            selectionCopyFeedbackTask?.cancel()
            selectionActionWindowController.showMenu(at: pendingUserCopyRead.location)
        }
        selectionReadTask = task
        selectionTaskRegistry.register(task, id: taskID)
        notifyWorkStateChange()
    }

    private func handleSelectionActionEffects(
        _ effects: [SelectionActionEffect],
        pendingSelectionRead: PendingSelectionRead? = nil
    ) {
        guard !isStopping else { return }
        for effect in effects {
            switch effect {
            case .scheduleRead(let delayMilliseconds):
                guard let pendingSelectionRead else { continue }
                SelectionActionDiagnostics.logRateLimited("effect scheduleRead delayMs=\(delayMilliseconds)")
                selectionReadTask?.cancel()
                let taskID = UUID()
                selectionReadTaskID = taskID
                let task = Task { [weak self] in
                    guard let self else { return }
                    defer {
                        self.selectionTaskRegistry.remove(id: taskID)
                        if self.selectionReadTaskID == taskID {
                            self.selectionReadTask = nil
                            self.selectionReadTaskID = nil
                            self.notifyWorkStateChange()
                        }
                    }
                    do {
                        try await Task.sleep(nanoseconds: UInt64(delayMilliseconds) * 1_000_000)
                    } catch {
                        return
                    }
                    guard !Task.isCancelled, !isStopping else { return }
                    await self.completeScheduledSelectionRead(pendingSelectionRead)
                }
                selectionReadTask = task
                selectionTaskRegistry.register(task, id: taskID)
                notifyWorkStateChange()
            case .cancelRead:
                SelectionActionDiagnostics.log("effect cancelRead")
                selectionReadTask?.cancel()
                selectionReadTask = nil
                selectionReadTaskID = nil
                notifyWorkStateChange()
            case .hidePanel:
                SelectionActionDiagnostics.log("effect hidePanel")
                selectionActionWindowController.hidePanel()
                notifyWorkStateChange()
            case .cancelWork:
                SelectionActionDiagnostics.log("effect cancelWork")
                selectionTranslationTask?.cancel()
                selectionTranslationTask = nil
                selectionTranslationTaskID = nil
                selectionTTSTask?.cancel()
                selectionTTSTask = nil
                selectionTTSTaskID = nil
                selectionCopyFeedbackTask?.cancel()
                speechPlaybackService.stop()
                isSelectionSpeechPlaying = false
                notifyWorkStateChange()
            case .showPanel(let text, let location):
                SelectionActionDiagnostics.log("effect showPanel length=\(text.count)")
                panelDismissalPolicy.recordPanelShown(at: Date().timeIntervalSinceReferenceDate)
                selectionActionMonitor.recordPanelShown()
                currentSelectionText = text
                currentTranslationText = ""
                selectionPronunciationReturnState = .menu
                selectionCopyFeedbackTask?.cancel()
                selectionActionWindowController.showMenu(at: location)
            case .showUnsupportedNotice:
                SelectionActionDiagnostics.log("effect showUnsupportedNotice")
                panelDismissalPolicy.recordPanelShown(at: Date().timeIntervalSinceReferenceDate)
                selectionActionMonitor.recordPanelShown()
                showSelectionUnsupportedNotice()
            }
        }
    }

    private func handleSelectionDismissRequest(reason: String = "unknown", bypassingPanelGrace: Bool = false) {
        guard !isStopping else { return }
        guard panelDismissalPolicy.shouldDismiss(
            at: Date().timeIntervalSinceReferenceDate,
            bypassingGrace: bypassingPanelGrace
        ) else {
            SelectionActionDiagnostics.log("panel dismiss suppressed during visibility grace reason=\(reason)")
            return
        }

        forceDismissSelectionActions(reason: reason)
    }

    func forceDismissSelectionActions(reason: String = "force") {
        guard !isStopping else { return }
        SelectionActionDiagnostics.log("force dismiss selection actions reason=\(reason)")
        handleSelectionActionEffects(selectionActionCoordinator.handle(.dismiss))
    }

    private func diagnosticSummary(for result: SelectedTextReadResult) -> String {
        switch result {
        case .success(let text):
            "success length=\(text.count)"
        case .permissionDenied:
            "permissionDenied"
        case .emptySelection:
            "emptySelection"
        case .unsupported:
            "unsupported"
        case .missingFocusedElement:
            "missingFocusedElement"
        case .failed(let message):
            "failed \(message)"
        }
    }

    private func completeScheduledSelectionRead(_ pendingSelectionRead: PendingSelectionRead) async {
        guard !isStopping, !isMigrationMaintenanceActive else { return }
        let config = (try? configStore.load()) ?? AppConfig.defaultConfig()
        let configuredForceSelectionMode = config.selectionActions.forceSelectionMode
        let forceSelectionMode: SelectionForceSelectionMode = if configuredForceSelectionMode == .menuCopyOnly,
                                                                 config.selectionActions.allowsSimulatedCopyFallback {
            .menuCopyThenShortcut
        } else {
            configuredForceSelectionMode
        }
        let readSelectedTextForAutomaticSelection = {
            await self.readSelectedTextForAutomaticSelection(
                pendingSelectionRead,
                forceSelectionMode: forceSelectionMode
            )
        }
        let result = await readSelectedTextForAutomaticSelection()
        guard !Task.isCancelled, !isStopping, !isMigrationMaintenanceActive else { return }
        SelectionActionDiagnostics.logRateLimited("read result \(diagnosticSummary(for: result))")
        handleSelectionActionEffects(selectionActionCoordinator.handle(.readCompleted(result)))
    }

    private func readSelectedTextForAutomaticSelection(
        _ pendingSelectionRead: PendingSelectionRead,
        forceSelectionMode: SelectionForceSelectionMode
    ) async -> SelectedTextReadResult {
        await selectionReadPipeline.readSelectedText(
            sourceProcessIdentifier: pendingSelectionRead.sourceProcessIdentifier,
            mouseLocation: pendingSelectionRead.location,
            forceSelectionMode: forceSelectionMode
        )
    }

    private func showSelectionUnsupportedNotice() {
        let point = SelectionPoint(x: NSEvent.mouseLocation.x, y: NSEvent.mouseLocation.y)
        currentSelectionText = ""
        currentTranslationText = ""
        selectionActionWindowController.showNotice(L10n.text("selection.action.unsupportedMessage"), at: point)
    }

    private func translateCurrentSelection() {
        guard !isStopping, !isMigrationMaintenanceActive else { return }
        let sourceText = currentSelectionText
        guard !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        selectionTranslationTask?.cancel()
        let taskID = UUID()
        selectionTranslationTaskID = taskID
        selectionActionWindowController.showTranslating()
        let task = Task { [weak self] in
            guard let self else { return }
            defer {
                self.selectionTaskRegistry.remove(id: taskID)
                if self.selectionTranslationTaskID == taskID {
                    self.selectionTranslationTask = nil
                    self.selectionTranslationTaskID = nil
                    self.notifyWorkStateChange()
                }
            }
            do {
                let config = try self.configStore.load()
                let providerPreset = config.resolvedProviderPreset
                let providerID = config.providerID
                let apiKeyStore = self.apiKeyStore
                let provider = OpenAIProvider(
                    apiKeyProvider: {
                        guard let apiKey = apiKeyStore.loadAPIKey(forProviderID: providerID),
                              !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        else {
                            throw TransformationError.provider(L10n.format("popover.error.missingAPIKey", providerPreset.name))
                        }
                        return apiKey
                    },
                    endpoint: providerPreset.endpoint
                )
                let targetLanguageName = config.selectionActions.translationLanguage.resolvedPromptTargetName(
                    interfaceLanguageCode: L10n.resolvedLanguage.localeIdentifier
                )
                let systemPrompt = config.selectionActions.effectiveTranslationPrompt(
                    targetLanguageName: targetLanguageName
                )
                let service = CachedSelectionTranslationService(
                    service: SelectionTranslationService(provider: provider),
                    cache: selectionTranslationCache
                )
                let translated = try await service.translate(
                    sourceText: sourceText,
                    targetLanguageName: targetLanguageName,
                    systemPrompt: systemPrompt,
                    model: config.model,
                    providerID: providerID,
                    timeoutSeconds: config.timeoutSeconds
                )
                guard !Task.isCancelled, !isStopping, !isMigrationMaintenanceActive else { return }
                try? self.historyStore.append(HistoryItem(
                    source: .selection,
                    inputText: sourceText,
                    outputText: translated,
                    modeName: nil,
                    targetLanguageName: targetLanguageName,
                    model: config.model,
                    metadata: ["providerID": providerID]
                ))
                await MainActor.run {
                    guard !self.isStopping else { return }
                    self.currentTranslationText = translated
                    self.selectionActionWindowController.showTranslation(translated)
                }
            } catch is CancellationError {
            } catch {
                if !self.isStopping, !self.isMigrationMaintenanceActive {
                    self.selectionActionWindowController.showTranslationError(
                        L10n.text("selection.action.translationFailed")
                    )
                }
            }
        }
        selectionTranslationTask = task
        selectionTaskRegistry.register(task, id: taskID)
        notifyWorkStateChange()
    }

    private func pronounceCurrentSelection() {
        pronounceSelectionText(currentSelectionText, returnState: .menu)
    }

    private func pronounceOriginalFromTranslation() {
        pronounceSelectionText(
            currentSelectionText,
            returnState: .translationResult,
            loadingFeedback: .loadingOriginalPronunciation,
            playingFeedback: .playingOriginalPronunciation
        )
    }

    private func pronounceCurrentTranslation() {
        pronounceSelectionText(
            currentTranslationText,
            returnState: .translationResult,
            loadingFeedback: .loadingTranslationPronunciation,
            playingFeedback: .playingTranslationPronunciation
        )
    }

    private func pronounceSelectionText(
        _ text: String,
        returnState: SelectionPronunciationReturnState,
        loadingFeedback: SelectionActionFeedback? = nil,
        playingFeedback: SelectionActionFeedback? = nil
    ) {
        guard !isStopping, !isMigrationMaintenanceActive else { return }
        let sourceText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sourceText.isEmpty else { return }

        selectionPronunciationReturnState = returnState
        selectionTTSTask?.cancel()
        let taskID = UUID()
        selectionTTSTaskID = taskID
        if returnState == .translationResult, !currentTranslationText.isEmpty {
            selectionActionWindowController.showTranslation(currentTranslationText, feedback: loadingFeedback)
        } else {
            selectionActionWindowController.showPreparingPronunciation()
        }
        let task = Task { [weak self] in
            guard let self else { return }
            defer {
                self.selectionTaskRegistry.remove(id: taskID)
                if self.selectionTTSTaskID == taskID {
                    self.selectionTTSTask = nil
                    self.selectionTTSTaskID = nil
                    self.notifyWorkStateChange()
                }
            }
            do {
                let provider = OpenAITTSProvider(apiKeyProvider: { [apiKeyStore] in
                    guard let apiKey = apiKeyStore.loadAPIKey(forProviderID: LLMProviderPreset.openAI.id),
                          !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    else {
                        throw OpenAITTSError.provider(L10n.text("selection.action.missingOpenAIKey"))
                    }
                    return apiKey
                })
                let config = (try? self.configStore.load()) ?? AppConfig.defaultConfig()
                let audioData = try await provider.speechAudio(OpenAITTSRequest(
                    input: sourceText,
                    voice: config.selectionActions.pronunciationVoice.rawValue,
                    speed: config.selectionActions.pronunciationSpeed,
                    timeoutSeconds: config.timeoutSeconds
                ))
                guard !Task.isCancelled, !isStopping, !isMigrationMaintenanceActive else { return }
                await MainActor.run {
                    guard !self.isStopping else { return }
                    do {
                        try self.speechPlaybackService.play(audioData: audioData)
                        self.isSelectionSpeechPlaying = true
                        self.notifyWorkStateChange()
                        if returnState == .menu {
                            self.selectionActionWindowController.showPlayingPronunciation()
                        } else if !self.currentTranslationText.isEmpty {
                            self.selectionActionWindowController.showTranslation(
                                self.currentTranslationText,
                                feedback: playingFeedback
                            )
                        }
                    } catch {
                        self.isSelectionSpeechPlaying = false
                        self.showSelectionPronunciationError(returnState: returnState)
                    }
                }
            } catch is CancellationError {
            } catch {
                if !self.isStopping, !self.isMigrationMaintenanceActive {
                    self.showSelectionPronunciationError(returnState: returnState)
                }
            }
        }
        selectionTTSTask = task
        selectionTaskRegistry.register(task, id: taskID)
        notifyWorkStateChange()
    }

    private func restoreSelectionPronunciationReturnState() {
        guard !isStopping, !isMigrationMaintenanceActive else { return }
        switch selectionPronunciationReturnState {
        case .menu:
            selectionActionWindowController.restoreMenu()
        case .translationResult:
            if currentTranslationText.isEmpty {
                selectionActionWindowController.restoreMenu()
            } else {
                selectionActionWindowController.showTranslation(currentTranslationText)
            }
        }
    }

    private func showSelectionPronunciationError(returnState: SelectionPronunciationReturnState) {
        guard !isStopping else { return }
        let message = L10n.text("selection.action.pronunciationFailed")
        switch returnState {
        case .menu:
            selectionActionWindowController.showPronunciationError(message)
        case .translationResult:
            if currentTranslationText.isEmpty {
                selectionActionWindowController.showPronunciationError(message)
            } else {
                selectionActionWindowController.showTranslation(currentTranslationText, errorMessage: message)
            }
        }
    }

    private func copyCurrentTranslation() {
        guard !isStopping, !isMigrationMaintenanceActive, !currentTranslationText.isEmpty else {
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(currentTranslationText, forType: .string)
        selectionCopyFeedbackTask?.cancel()
        selectionActionWindowController.showTranslation(currentTranslationText, feedback: .copiedTranslation)
        let taskID = UUID()
        selectionCopyFeedbackTaskID = taskID
        let task = Task { [weak self, copiedText = currentTranslationText] in
            defer {
                if let self {
                    self.selectionTaskRegistry.remove(id: taskID)
                    if self.selectionCopyFeedbackTaskID == taskID {
                        self.selectionCopyFeedbackTask = nil
                        self.selectionCopyFeedbackTaskID = nil
                    }
                }
            }
            try? await Task.sleep(for: .milliseconds(900))
            await MainActor.run {
                guard let self,
                      !self.isStopping,
                      self.currentTranslationText == copiedText
                else {
                    return
                }
                self.selectionActionWindowController.showTranslation(self.currentTranslationText)
            }
        }
        selectionCopyFeedbackTask = task
        selectionTaskRegistry.register(task, id: taskID)
    }
}
