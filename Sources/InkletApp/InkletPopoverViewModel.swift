import Combine
import AppKit
import SwiftUI
import InkletCore

@MainActor
final class InkletPopoverViewModel: ObservableObject {
    @Published var sourceText = ""
    @Published var resultText = ""
    @Published var errorMessage: String?
    @Published var isTransforming = false
    @Published var isInserting = false
    @Published private(set) var modePickerState: WritingModePickerState
    @Published private(set) var popoverSession: WritingPopoverSessionState
    @Published private(set) var modeSearchFocusRevision = 0
    @Published private(set) var modes: [PromptMode]
    @Published var preferredPopoverHeight: CGFloat = 168
    @Published var appearance: AppAppearance
    @Published var voiceShortcutHint: VoiceInputConfig.Shortcut?
    @Published private(set) var dictationPhase: WritingDictationCoordinator.Phase = .idle

    var onHidePopover: (() -> Void)?
    var onFocusPopover: (() -> Void)?
    var onFocusSourceInput: ((FocusRequestGeneration.Request) -> Void)?
    var onOpenSettings: (() -> Void)?
    var onCancelDictation: (() -> Void)?

    var route: WritingPopoverSessionState.Route {
        popoverSession.route
    }

    var selectedModeID: String {
        popoverSession.selectedModeID
    }

    var isResultStale: Bool {
        popoverSession.isResultStale && !resultText.isEmpty
    }

    var resultModeDisplayName: String? {
        guard let resultModeID = popoverSession.resultModeID else {
            return nil
        }

        return modes.first(where: { $0.id == resultModeID })?.localizedName ?? resultModeID
    }

    var currentProviderName: String {
        LLMProviderPreset.preset(id: config.providerID).name
    }

    var currentModelName: String {
        config.model
    }

    var currentVoiceInputConfig: VoiceInputConfig {
        config.voiceInput
    }

    var shouldShowDictationStatus: Bool {
        voiceShortcutHint != nil || dictationPhase.isActive
    }

    var dictationStatusText: String {
        switch dictationPhase {
        case .connecting:
            L10n.text("dictation.status.connecting")
        case .listening:
            L10n.text("dictation.status.listening")
        case .recordingForFallback:
            L10n.text("dictation.status.recordingFallback")
        case .finalizing:
            L10n.text("dictation.status.finalizing")
        case .recovering:
            L10n.text("dictation.status.recovering")
        case .idle, .complete, .failed:
            L10n.format("dictation.hint.hold", voiceShortcutHint?.localizedName ?? "")
        }
    }

    var dictationStatusAccessibilityLabel: String {
        switch dictationPhase {
        case .listening:
            L10n.text("dictation.accessibility.listening")
        case .recordingForFallback:
            L10n.text("dictation.accessibility.recordingFallback")
        case .connecting, .finalizing, .recovering:
            dictationStatusText
        case .idle, .complete, .failed:
            L10n.text("dictation.accessibility.ready")
        }
    }

    private struct SourceDictationPresentationSnapshot {
        let sourceText: String
        let resultText: String
        let errorMessage: String?
        let popoverSession: WritingPopoverSessionState
        let stateMachineState: PopoverStateMachine.State
        let draftSourceText: String
        let hasTransformedInSession: Bool
    }

    private var stateMachine: PopoverStateMachine
    private let configStore: UserDefaultsConfigStore
    private let apiKeyStore: LocalAPIKeyStore
    private let insertionService: InsertionService
    private let transformationServiceFactory: (any LLMProvider) -> TransformationService
    private let historyStore: any HistoryStore
    private let writingModePreferenceStore: WritingModePreferenceStore
    private var config: AppConfig
    private var previousApplication: NSRunningApplication?
    private var transformationTask: Task<Void, Never>?
    private var insertionTask: Task<Void, Never>?
    private var sessionID = 0
    private var draftSourceText = ""
    private var hasTransformedInSession = false
    private var sourceFocusGeneration = FocusRequestGeneration()
    private var sourceDictationPresentationSnapshot: SourceDictationPresentationSnapshot?
    private var isRestoringSourceDictationPresentation = false
    private var languageCancellable: AnyCancellable?
    private var dictationErrorMessage: String?

    init(
        stateMachine: PopoverStateMachine = PopoverStateMachine(),
        configStore: UserDefaultsConfigStore = UserDefaultsConfigStore(),
        apiKeyStore: LocalAPIKeyStore = LocalAPIKeyStore(),
        transformationServiceFactory: @escaping (any LLMProvider) -> TransformationService = { TransformationService(provider: $0) },
        insertionService: InsertionService = InsertionService(),
        historyStore: any HistoryStore = JSONLHistoryStore(),
        writingModePreferenceStore: WritingModePreferenceStore = WritingModePreferenceStore()
    ) {
        self.stateMachine = stateMachine
        self.configStore = configStore
        self.apiKeyStore = apiKeyStore
        self.transformationServiceFactory = transformationServiceFactory
        self.insertionService = insertionService
        self.historyStore = historyStore
        self.writingModePreferenceStore = writingModePreferenceStore

        let loadedConfig = (try? configStore.load()) ?? AppConfig.defaultConfig()
        let selectedModeID = Self.resolvedModeID(
            preferredModeID: writingModePreferenceStore.loadLastModeID(),
            config: loadedConfig
        )
        let visibleModes = Self.resolvedVisibleModes(from: loadedConfig)
        self.config = loadedConfig
        self.modes = visibleModes
        self.modePickerState = WritingModePickerState(
            items: Self.modePickerItems(for: visibleModes),
            preferredModeID: selectedModeID
        )
        self.popoverSession = WritingPopoverSessionState(selectedModeID: selectedModeID)
        self.appearance = loadedConfig.appearance
        self.voiceShortcutHint = nil
        languageCancellable = NotificationCenter.default.publisher(for: .inkletLanguageDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshLocalizedContent()
            }
    }

    private func refreshLocalizedContent() {
        modePickerState = WritingModePickerState(
            items: Self.modePickerItems(for: modes),
            preferredModeID: modePickerState.highlightedModeID,
            query: modePickerState.query
        )
        if case .failed(let errorKey) = dictationPhase, errorMessage == dictationErrorMessage {
            errorMessage = L10n.text(errorKey)
            dictationErrorMessage = errorMessage
        }
    }

    func resetForOpen(previousApplication: NSRunningApplication?) {
        invalidateSourceInputFocusRequests()
        transformationTask?.cancel()
        transformationTask = nil
        insertionTask?.cancel()
        insertionTask = nil
        sessionID += 1
        self.previousApplication = previousApplication
        stateMachine = PopoverStateMachine()

        config = (try? configStore.load()) ?? AppConfig.defaultConfig()
        let selectedModeID = Self.resolvedModeID(
            preferredModeID: writingModePreferenceStore.loadLastModeID(),
            config: config
        )
        modes = Self.resolvedVisibleModes(from: config)
        popoverSession = WritingPopoverSessionState(selectedModeID: selectedModeID)
        modePickerState = WritingModePickerState(
            items: Self.modePickerItems(for: modes),
            preferredModeID: selectedModeID
        )
        modeSearchFocusRevision += 1
        appearance = config.appearance
        refreshVoiceShortcutHint()
        sourceText = draftSourceText
        resultText = ""
        errorMessage = nil
        isTransforming = false
        isInserting = false
        hasTransformedInSession = false
        sourceDictationPresentationSnapshot = nil
        dictationPhase = .idle
        preferredPopoverHeight = WritingModePickerView.preferredHeight(
            resultCount: modePickerState.filteredItems.count
        )

        handle(actions: stateMachine.send(.open))
        if !sourceText.isEmpty {
            _ = stateMachine.send(.sourceChanged(sourceText))
        }
    }

    var isBusy: Bool {
        isTransforming || isInserting || dictationPhase.isActive
    }

    func cancelForMigrationMaintenance() {
        sessionID += 1
        transformationTask?.cancel()
        transformationTask = nil
        insertionTask?.cancel()
        insertionTask = nil
        isTransforming = false
        isInserting = false
    }

    private func refreshVoiceShortcutHint() {
        let shortcut = config.voiceInput.shortcut
        voiceShortcutHint = shortcut == .disabled ? nil : shortcut
    }

    func beginSourceDictationPresentation() -> Bool {
        guard route == .editor,
              !isBusy,
              !isRestoringSourceDictationPresentation,
              sourceDictationPresentationSnapshot == nil
        else {
            return false
        }

        sourceDictationPresentationSnapshot = SourceDictationPresentationSnapshot(
            sourceText: sourceText,
            resultText: resultText,
            errorMessage: errorMessage,
            popoverSession: popoverSession,
            stateMachineState: stateMachine.state,
            draftSourceText: draftSourceText,
            hasTransformedInSession: hasTransformedInSession
        )
        errorMessage = nil
        return true
    }

    func synchronizeSourceTextDuringDictation(_ text: String) {
        guard sourceDictationPresentationSnapshot != nil else {
            return
        }
        sourceText = text
    }

    func commitSourceDictationPresentation() {
        guard sourceDictationPresentationSnapshot != nil else {
            return
        }
        sourceDictationPresentationSnapshot = nil
        resultText = ""
        errorMessage = nil
        mutatePopoverSession { $0.clearResult() }
        draftSourceText = sourceText
        hasTransformedInSession = false
        stateMachine = PopoverStateMachine(
            state: .editingSource(source: sourceText, errorMessage: nil)
        )
    }

    func synchronizeSourceTextAfterDictation(_ text: String) {
        sourceText = text
        resultText = ""
        errorMessage = nil
        mutatePopoverSession { $0.clearResult() }
        draftSourceText = text
        hasTransformedInSession = false
        stateMachine = PopoverStateMachine(
            state: .editingSource(source: text, errorMessage: nil)
        )
    }

    func restoreSourceDictationPresentation() {
        guard let snapshot = sourceDictationPresentationSnapshot,
              !isRestoringSourceDictationPresentation
        else {
            return
        }
        isRestoringSourceDictationPresentation = true
        defer {
            sourceDictationPresentationSnapshot = nil
            isRestoringSourceDictationPresentation = false
        }
        sourceText = snapshot.sourceText
        resultText = snapshot.resultText
        errorMessage = snapshot.errorMessage
        popoverSession = snapshot.popoverSession
        stateMachine = PopoverStateMachine(state: snapshot.stateMachineState)
        draftSourceText = snapshot.draftSourceText
        hasTransformedInSession = snapshot.hasTransformedInSession
    }

    func setDictationPhase(_ phase: WritingDictationCoordinator.Phase) {
        dictationPhase = phase
        if case .failed(let errorKey) = phase {
            errorMessage = L10n.text(errorKey)
            dictationErrorMessage = errorMessage
        }
    }

    func updateSourceText(_ text: String) {
        guard !isBusy else {
            return
        }

        sourceText = text
        if !resultText.isEmpty {
            resultText = ""
            mutatePopoverSession { $0.clearResult() }
        }

        _ = stateMachine.send(.sourceChanged(text))
    }

    func updateResultText(_ text: String) {
        guard !isBusy else {
            return
        }

        resultText = text
        guard !text.isEmpty else {
            mutatePopoverSession { $0.clearResult() }
            stateMachine = PopoverStateMachine(
                state: .editingSource(source: sourceText, errorMessage: nil)
            )
            return
        }

        _ = stateMachine.send(.resultChanged(text))
    }

    func updateModeSearchQuery(_ query: String) {
        guard !isBusy else {
            return
        }
        mutateModePickerState { $0.setQuery(query) }
    }

    func moveModeHighlight(by offset: Int) {
        guard !isBusy else {
            return
        }
        mutateModePickerState { $0.moveHighlight(by: offset) }
    }

    func highlightMode(modeID: String) {
        guard !isBusy else {
            return
        }
        mutateModePickerState { _ = $0.highlight(modeID: modeID) }
    }

    func commitHighlightedMode() {
        guard let highlightedModeID = modePickerState.highlightedModeID else {
            return
        }

        commitMode(modeID: highlightedModeID)
    }

    func commitMode(modeID: String) {
        guard !isBusy,
              modes.contains(where: { $0.id == modeID })
        else {
            return
        }

        mutatePopoverSession { $0.enterEditor(modeID: modeID) }
        writingModePreferenceStore.saveLastModeID(modeID)
        requestSourceInputFocus()
    }

    func returnToModePicker() {
        guard !isBusy else {
            return
        }

        invalidateSourceInputFocusRequests()
        mutatePopoverSession { $0.showModePicker() }
        modePickerState = WritingModePickerState(
            items: Self.modePickerItems(for: modes),
            preferredModeID: selectedModeID
        )
        modeSearchFocusRevision += 1
    }

    func cyclePromptMode(direction: Int) {
        guard !modes.isEmpty else {
            return
        }

        let currentIndex = modes.firstIndex { $0.id == selectedModeID } ?? 0
        let nextIndex = (currentIndex + direction + modes.count) % modes.count
        commitMode(modeID: modes[nextIndex].id)
    }

    func submit() {
        guard !isBusy else {
            return
        }

        errorMessage = nil
        if !resultText.isEmpty, isResultStale {
            removeSingleTrailingNewlineFromSource()
            _ = stateMachine.send(.sourceChanged(sourceText))
            handle(actions: stateMachine.send(.submit))
            return
        }

        if !resultText.isEmpty {
            removeSingleTrailingNewlineFromResult()
            let currentResult = resultText
            _ = stateMachine.send(.resultChanged(currentResult))
            let actions = stateMachine.send(.submit)
            if actions.isEmpty {
                insert(
                    text: currentResult,
                    fallbackState: .previewingResult(source: sourceText, result: currentResult)
                )
            } else {
                handle(actions: actions)
            }
            return
        }

        removeSingleTrailingNewlineFromSource()
        _ = stateMachine.send(.sourceChanged(sourceText))
        handle(actions: stateMachine.send(.submit))
    }

    private func removeSingleTrailingNewlineFromSource() {
        if sourceText.hasSuffix("\r\n") {
            sourceText.removeLast(2)
        } else if sourceText.hasSuffix("\n") || sourceText.hasSuffix("\r") {
            sourceText.removeLast()
        }
    }

    private func removeSingleTrailingNewlineFromResult() {
        if resultText.hasSuffix("\r\n") {
            resultText.removeLast(2)
        } else if resultText.hasSuffix("\n") || resultText.hasSuffix("\r") {
            resultText.removeLast()
        }
    }

    func insertOriginal() {
        guard !isBusy else {
            return
        }

        let trimmedSource = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSource.isEmpty else {
            errorMessage = L10n.text("popover.error.emptyOriginal")
            return
        }

        errorMessage = nil
        let fallbackState: PopoverStateMachine.State = resultText.isEmpty
            ? .editingSource(source: sourceText, errorMessage: nil)
            : .previewingResult(source: sourceText, result: resultText)

        if resultText.isEmpty {
            _ = stateMachine.send(.sourceChanged(sourceText))
            let actions = stateMachine.send(.insertOriginal)
            if !actions.isEmpty {
                handle(actions: actions)
                return
            }
        }

        insert(text: sourceText, fallbackState: fallbackState)
    }

    func escape() {
        if dictationPhase.isActive {
            onCancelDictation?()
            return
        }

        if isTransforming {
            cancelTransformationAndStayInEditor()
            return
        }

        guard !isInserting else {
            return
        }

        if route == .modePicker {
            draftSourceText = hasTransformedInSession ? "" : sourceText
            handle(actions: stateMachine.send(.close))
            return
        }

        if !resultText.isEmpty {
            resultText = ""
            errorMessage = nil
            mutatePopoverSession { $0.clearResult() }
            stateMachine = PopoverStateMachine(
                state: .editingSource(source: sourceText, errorMessage: nil)
            )
            requestSourceInputFocus()
            return
        }

        returnToModePicker()
    }

    func openSettings() {
        guard !isBusy else {
            return
        }
        onHidePopover?()
        onOpenSettings?()
    }

    func isCurrentSourceFocusRequest(_ request: FocusRequestGeneration.Request) -> Bool {
        sourceFocusGeneration.isCurrent(request)
    }

    private func requestSourceInputFocus() {
        guard route == .editor else {
            return
        }

        let request = sourceFocusGeneration.issue()
        onFocusSourceInput?(request)
    }

    private func invalidateSourceInputFocusRequests() {
        sourceFocusGeneration.invalidate()
    }

    private func handle(actions: [PopoverStateMachine.Action]) {
        for action in actions {
            switch action {
            case .showPopover:
                onFocusPopover?()
            case .hidePopover:
                onHidePopover?()
            case .focusSourceInput:
                requestSourceInputFocus()
            case .startTransformation(let source):
                startTransformation(source: source)
            case .showResult(let result):
                hasTransformedInSession = true
                draftSourceText = ""
                resultText = result
            case .showError(let message):
                errorMessage = localizedStateMachineMessage(message)
            case .insertText(let text):
                let fallbackState: PopoverStateMachine.State
                if !resultText.isEmpty {
                    fallbackState = .previewingResult(source: sourceText, result: resultText)
                } else {
                    fallbackState = .editingSource(source: sourceText, errorMessage: nil)
                }
                insert(text: text, fallbackState: fallbackState)
            }
        }
    }

    private func startTransformation(source: String) {
        transformationTask?.cancel()
        let preservesExistingResult = isResultStale
        if !preservesExistingResult {
            resultText = ""
            mutatePopoverSession { $0.clearResult() }
        }
        errorMessage = nil
        isTransforming = true

        let resolvedModeID = Self.resolvedModeID(
            preferredModeID: selectedModeID,
            visibleModes: modes
        )
        let mode = PromptModeStore(modes: modes).resolve(
            modeID: resolvedModeID,
            sourceText: source
        )
        let transformationModeID = mode.id
        let model = config.model
        let timeoutSeconds = config.timeoutSeconds
        let providerPreset = config.resolvedProviderPreset
        let providerID = config.providerID
        let apiKeyStore = self.apiKeyStore
        let provider = LLMProviderFactory.provider(for: providerPreset) {
            try LocalAPIKeyProvider(
                apiKeyStore: apiKeyStore,
                providerID: providerID,
                providerName: providerPreset.name
            ).loadAPIKey()
        }
        let transformationService = transformationServiceFactory(provider)

        transformationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await transformationService.transform(
                    sourceText: source,
                    mode: mode,
                    model: model,
                    timeoutSeconds: timeoutSeconds
                )
                guard !Task.isCancelled else { return }
                try? historyStore.append(HistoryItem(
                    source: .write,
                    inputText: source,
                    outputText: result.outputText,
                    modeName: mode.localizedName,
                    targetLanguageName: nil,
                    model: model,
                    metadata: [
                        "modeID": mode.id,
                        "providerID": providerID
                    ]
                ))
                transformationTask = nil
                isTransforming = false
                mutatePopoverSession { $0.recordResult(modeID: transformationModeID) }
                handle(actions: stateMachine.send(.transformationSucceeded(result: result.outputText)))
            } catch {
                guard !Task.isCancelled else { return }
                transformationTask = nil
                isTransforming = false
                if !preservesExistingResult {
                    resultText = ""
                    mutatePopoverSession { $0.clearResult() }
                }
                handle(actions: stateMachine.send(.transformationFailed(message: error.userFacingMessage)))
                if preservesExistingResult {
                    synchronizeStateMachineWithVisibleContent()
                }
            }
        }
    }

    private func cancelTransformationAndStayInEditor() {
        transformationTask?.cancel()
        transformationTask = nil
        isTransforming = false
        errorMessage = nil
        mutatePopoverSession { $0.enterEditor(modeID: selectedModeID) }
        synchronizeStateMachineWithVisibleContent()
    }

    private func synchronizeStateMachineWithVisibleContent() {
        let visibleState: PopoverStateMachine.State = resultText.isEmpty
            ? .editingSource(source: sourceText, errorMessage: nil)
            : .previewingResult(source: sourceText, result: resultText)
        stateMachine = PopoverStateMachine(state: visibleState)
    }

    private func mutateModePickerState(_ mutation: (inout WritingModePickerState) -> Void) {
        var updatedState = modePickerState
        mutation(&updatedState)
        modePickerState = updatedState
    }

    private func mutatePopoverSession(_ mutation: (inout WritingPopoverSessionState) -> Void) {
        var updatedSession = popoverSession
        mutation(&updatedSession)
        popoverSession = updatedSession
    }

    private static func resolvedModeID(
        preferredModeID: String?,
        config: AppConfig
    ) -> String {
        guard let preferredModeID else {
            return config.defaultVisibleModeID
        }

        return config.visibleModeID(preferredModeID: preferredModeID)
    }

    private static func resolvedVisibleModes(from config: AppConfig) -> [PromptMode] {
        let visibleModes = config.visiblePromptModes
        if !visibleModes.isEmpty {
            return visibleModes
        }

        return AppConfig.defaultConfig().visiblePromptModes
    }

    private static func resolvedModeID(
        preferredModeID: String?,
        visibleModes: [PromptMode]
    ) -> String {
        if let preferredModeID,
           visibleModes.contains(where: { $0.id == preferredModeID }) {
            return preferredModeID
        }

        return visibleModes.first?.id ?? PromptMode.translateToEnglishID
    }

    private static func modePickerItems(for modes: [PromptMode]) -> [WritingModePickerItem] {
        modes.map { WritingModePickerItem(id: $0.id, title: $0.localizedName) }
    }

    private func localizedStateMachineMessage(_ message: String) -> String {
        switch message {
        case "请输入要转换的文本":
            L10n.text("error.emptySource")
        default:
            message
        }
    }

    private func insert(text: String, fallbackState: PopoverStateMachine.State) {
        guard let previousApplication else {
            stateMachine = PopoverStateMachine(state: fallbackState)
            errorMessage = L10n.text("popover.error.missingTarget")
            return
        }

        errorMessage = nil
        onHidePopover?()
        isInserting = true

        let insertionSessionID = sessionID
        insertionTask?.cancel()
        insertionTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await insertionService.insert(text: text, into: previousApplication)
                guard sessionID == insertionSessionID else {
                    return
                }
                isInserting = false
                insertionTask = nil
                draftSourceText = ""
                sourceText = ""
                resultText = ""
                mutatePopoverSession { $0.clearResult() }
                handle(actions: stateMachine.send(.insertionFinished))
            } catch {
                guard sessionID == insertionSessionID else {
                    return
                }
                isInserting = false
                insertionTask = nil
                stateMachine = PopoverStateMachine(state: fallbackState)
                errorMessage = error.userFacingMessage
                onFocusPopover?()
            }
        }
    }
}

private struct LocalAPIKeyProvider: @unchecked Sendable {
    let apiKeyStore: LocalAPIKeyStore
    let providerID: String
    let providerName: String

    func loadAPIKey() throws -> String {
        guard let apiKey = apiKeyStore.loadAPIKey(forProviderID: providerID),
              !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw TransformationError.provider(L10n.format("popover.error.missingAPIKey", providerName))
        }
        return apiKey
    }
}

private extension Error {
    var userFacingMessage: String {
        if let transformationError = self as? TransformationError {
            switch transformationError {
            case .emptySource:
                return L10n.text("error.emptySource")
            case .emptyResponse:
                return L10n.text("error.emptyResponse")
            case .timeout:
                return L10n.text("error.timeout")
            case .networkConnectionLost:
                return L10n.text("error.networkConnectionLost")
            case .provider(let message):
                return localizedProviderMessage(message)
            }
        }

        if let localizedError = self as? LocalizedError,
           let description = localizedError.errorDescription {
            return description
        }

        if let insertionError = self as? InsertionError {
            switch insertionError {
            case .accessibilityPermissionMissing:
                return L10n.text("insertion.error.accessibility")
            case .activationFailed:
                return L10n.text("insertion.error.activation")
            case .cannotCreatePasteEvent:
                return L10n.text("insertion.error.pasteEvent")
            case .clipboardRestoreFailed:
                return L10n.text("insertion.error.clipboardRestore")
            }
        }

        return String(describing: self)
    }

    private func localizedProviderMessage(_ message: String) -> String {
        for providerName in LLMProviderPreset.all.map(\.name) {
            let prefix = "\(providerName) 请求失败："
            guard message.hasPrefix(prefix) else {
                continue
            }

            let detail = String(message.dropFirst(prefix.count))
            if detail == "URL 无效" {
                return L10n.format("error.provider.urlInvalid", providerName)
            }
            if detail == "HTTP unknown" {
                return L10n.format("error.provider.httpUnknown", providerName)
            }
            return L10n.format("error.provider.prefix", providerName, detail)
        }

        return message
    }
}
