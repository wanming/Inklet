import AppKit
import Combine
import SwiftUI
import InkletCore

enum PronunciationPreviewState: Equatable {
    case loading(SelectionPronunciationVoice)
    case playing(SelectionPronunciationVoice)

    func matches(_ voice: SelectionPronunciationVoice) -> Bool {
        switch self {
        case .loading(let activeVoice), .playing(let activeVoice):
            activeVoice == voice
        }
    }
}

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var config: AppConfig
    @Published var message: String
    @Published var providerAPIKey: String
    @Published var selectedPromptModeID: String
    @Published var interfaceLanguage: InterfaceLanguage
    @Published var cachedProviderModels: [String: [String]]
    @Published var isRefreshingModelCatalog: Bool
    @Published var isEditingCustomModel: Bool
    @Published var microphoneOptions: [MicrophoneDeviceOption]
    @Published private(set) var pronunciationPreviewState: PronunciationPreviewState?
    @Published var permissionRefreshID: UUID
    @Published var historyItems: [HistoryItem]
    @Published var historyFilter: HistorySource?
    @Published private(set) var isMigrationMaintenanceActive = false
    @Published private(set) var isMigrationWorkflowIdle = true

    private let configStore: UserDefaultsConfigStore
    private let apiKeyStore: LocalAPIKeyStore
    private let modelCatalogService: ModelCatalogService
    private let historyStore: any HistoryStore
    private let microphoneDeviceCatalog: MicrophoneDeviceCatalog
    private let pronunciationPreviewPlaybackService: SpeechPlaybackService
    private var autoSaveCancellable: AnyCancellable?
    private var pronunciationPreviewTasks: [UUID: Task<Void, Never>] = [:]
    private var pronunciationPreviewTaskID: UUID?
    private var modelCatalogRefreshTask: Task<Void, Never>?
    private var modelCatalogRefreshTaskID: UUID?
    private var savedConfig: AppConfig
    private var savedProviderAPIKey: String
    private var savedInterfaceLanguage: InterfaceLanguage

    static let customModelMenuID = "__custom_model__"

    init(
        configStore: UserDefaultsConfigStore = UserDefaultsConfigStore(),
        apiKeyStore: LocalAPIKeyStore = LocalAPIKeyStore(),
        modelCatalogService: ModelCatalogService = ModelCatalogService(),
        historyStore: any HistoryStore = JSONLHistoryStore(),
        microphoneDeviceCatalog: MicrophoneDeviceCatalog = MicrophoneDeviceCatalog()
    ) {
        var loadedConfig = (try? configStore.load()) ?? AppConfig.defaultConfig()
        self.configStore = configStore
        self.apiKeyStore = apiKeyStore
        self.modelCatalogService = modelCatalogService
        self.historyStore = historyStore
        self.microphoneDeviceCatalog = microphoneDeviceCatalog
        self.pronunciationPreviewPlaybackService = SpeechPlaybackService()
        loadedConfig.providerID = LLMProviderPreset.openAI.id
        self.config = loadedConfig
        self.savedConfig = loadedConfig
        self.message = ""
        self.interfaceLanguage = InkletLanguageStore.selectedLanguage
        self.savedInterfaceLanguage = InkletLanguageStore.selectedLanguage
        let loadedProviderAPIKey = apiKeyStore.loadAPIKey(forProviderID: LLMProviderPreset.openAI.id) ?? ""
        self.providerAPIKey = loadedProviderAPIKey
        self.savedProviderAPIKey = loadedProviderAPIKey
        self.selectedPromptModeID = loadedConfig.promptModes.sorted { $0.sortOrder < $1.sortOrder }.first?.id
            ?? PromptMode.translateToEnglishID
        self.cachedProviderModels = Dictionary(
            uniqueKeysWithValues: LLMProviderPreset.all.compactMap { preset in
                guard let modelIDs = modelCatalogService.cachedModelIDs(for: preset.id) else {
                    return nil
                }
                return (preset.id, modelIDs)
            }
        )
        self.isRefreshingModelCatalog = false
        self.isEditingCustomModel = false
        self.microphoneOptions = microphoneDeviceCatalog.options()
        self.pronunciationPreviewState = nil
        self.permissionRefreshID = UUID()
        self.historyItems = (try? historyStore.load()).map { Array($0.reversed()) } ?? []
        self.historyFilter = nil

        self.pronunciationPreviewPlaybackService.onFinish = { [weak self] in
            self?.pronunciationPreviewState = nil
            self?.refreshMigrationWorkflowIdle()
        }
        installAutoSave()
    }

    var selectedProvider: LLMProviderPreset {
        LLMProviderPreset.openAI
    }

    var filteredHistoryItems: [HistoryItem] {
        guard let historyFilter else {
            return historyItems
        }
        return historyItems.filter { $0.source == historyFilter }
    }

    var isCustomOpenAICompatibleProvider: Bool {
        false
    }

    var selectedProviderModelOptions: [String] {
        guard !isCustomOpenAICompatibleProvider else {
            return []
        }

        var seen = Set<String>()
        var options: [String] = []

        for modelID in cachedProviderModels[LLMProviderPreset.openAI.id] ?? [] {
            if seen.insert(modelID).inserted {
                options.append(modelID)
            }
        }

        if seen.insert(selectedProvider.defaultModel).inserted {
            options.insert(selectedProvider.defaultModel, at: 0)
        }

        return options
    }

    var selectedModelMenuValue: String {
        if isEditingCustomModel {
            return Self.customModelMenuID
        }

        return selectedProviderModelOptions.contains(config.model) ? config.model : Self.customModelMenuID
    }

    var shouldShowCustomModelField: Bool {
        isCustomOpenAICompatibleProvider || selectedModelMenuValue == Self.customModelMenuID
    }

    var selectedModelIsDefault: Bool {
        config.model.trimmingCharacters(in: .whitespacesAndNewlines) == selectedProvider.defaultModel
    }

    var selectedPromptModeIndex: Int? {
        config.promptModes.firstIndex { $0.id == selectedPromptModeID }
    }

    var orderedPromptModes: [PromptMode] {
        config.promptModes.sorted { lhs, rhs in
            if lhs.sortOrder == rhs.sortOrder {
                return lhs.name < rhs.name
            }
            return lhs.sortOrder < rhs.sortOrder
        }
    }

    var isAccessibilityTrusted: Bool {
        AccessibilityPermissionService().isTrusted
    }

    func refreshPermissions() {
        permissionRefreshID = UUID()
    }

    func reloadHistory() {
        do {
            historyItems = Array(try historyStore.load().reversed())
        } catch {
            historyItems = []
            message = L10n.text("settings.history.error.loadFailed")
        }
    }

    func clearHistory() {
        guard !isMigrationMaintenanceActive else { return }
        do {
            try historyStore.clear()
            historyItems = []
            message = L10n.text("settings.history.cleared")
        } catch {
            message = L10n.text("settings.history.error.clearFailed")
        }
    }

    func refreshMicrophoneOptions() {
        microphoneOptions = microphoneDeviceCatalog.options()
        if let microphoneDeviceID = config.voiceInput.microphoneDeviceID,
           !microphoneOptions.contains(where: { $0.deviceID == microphoneDeviceID }) {
            config.voiceInput.microphoneDeviceID = nil
        }
    }

    var selectedMicrophoneMenuID: String {
        get {
            guard let microphoneDeviceID = config.voiceInput.microphoneDeviceID,
                  microphoneOptions.contains(where: { $0.deviceID == microphoneDeviceID })
            else {
                return MicrophoneDeviceOption.systemDefaultID
            }
            return microphoneDeviceID
        }
        set {
            config.voiceInput.microphoneDeviceID = newValue == MicrophoneDeviceOption.systemDefaultID ? nil : newValue
        }
    }

    func modelMenuTitle(for modelID: String) -> String {
        if modelID == config.model, !selectedModelIsDefault {
            return "\(modelID) *"
        }
        return modelID
    }

    func selectModelMenuValue(_ value: String) {
        if value == Self.customModelMenuID {
            isEditingCustomModel = true
            return
        }

        isEditingCustomModel = false
        config.model = value
        save()
    }

    func previewPronunciationVoice() {
        guard !isMigrationMaintenanceActive else { return }
        let voice = config.selectionActions.pronunciationVoice
        let speed = config.selectionActions.pronunciationSpeed
        if let pronunciationPreviewTaskID {
            pronunciationPreviewTasks[pronunciationPreviewTaskID]?.cancel()
        }
        pronunciationPreviewPlaybackService.stop()
        pronunciationPreviewState = .loading(voice)
        let taskID = UUID()
        pronunciationPreviewTaskID = taskID

        let task = Task { [weak self] in
            defer {
                self?.pronunciationPreviewTasks[taskID] = nil
                if self?.pronunciationPreviewTaskID == taskID {
                    self?.pronunciationPreviewTaskID = nil
                }
                self?.refreshMigrationWorkflowIdle()
            }
            do {
                guard let self else { return }
                let provider = OpenAITTSProvider(apiKeyProvider: { [apiKeyStore] in
                    guard let apiKey = apiKeyStore.loadAPIKey(forProviderID: LLMProviderPreset.openAI.id),
                          !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    else {
                        throw OpenAITTSError.provider(L10n.text("selection.action.missingOpenAIKey"))
                    }
                    return apiKey
                })
                let audioData = try await provider.speechAudio(OpenAITTSRequest(
                    input: SelectionPronunciationVoice.previewText(
                        interfaceLanguageCode: L10n.resolvedLanguage.localeIdentifier
                    ),
                    voice: voice.rawValue,
                    speed: speed,
                    timeoutSeconds: config.timeoutSeconds
                ))
                guard !Task.isCancelled,
                      pronunciationPreviewTaskID == taskID,
                      !isMigrationMaintenanceActive
                else {
                    return
                }
                await MainActor.run {
                    do {
                        try self.pronunciationPreviewPlaybackService.play(audioData: audioData)
                        self.pronunciationPreviewState = .playing(voice)
                    } catch {
                        self.pronunciationPreviewState = nil
                        self.message = L10n.text("selection.action.pronunciationFailed")
                    }
                }
            } catch is CancellationError {
            } catch {
                guard !Task.isCancelled, self?.pronunciationPreviewTaskID == taskID else { return }
                await MainActor.run {
                    self?.pronunciationPreviewState = nil
                    self?.message = L10n.text("selection.action.pronunciationFailed")
                }
            }
        }
        pronunciationPreviewTasks[taskID] = task
        refreshMigrationWorkflowIdle()
    }

    func resetSelectionTranslationPrompt() {
        config.selectionActions.translationPrompt = SelectionActionsConfig.defaultTranslationPrompt
        save()
    }

    func refreshModelCatalogIfNeeded() async {
        guard !isMigrationMaintenanceActive else { return }
        if let modelCatalogRefreshTask {
            await modelCatalogRefreshTask.value
            return
        }

        isRefreshingModelCatalog = true
        let taskID = UUID()
        modelCatalogRefreshTaskID = taskID
        let modelCatalogService = self.modelCatalogService
        let task = Task<Void, Never> {
            do {
                try await modelCatalogService.refreshIfNeeded()
            } catch {
                // The model picker still works with saved/default/custom values when refresh fails.
            }
        }
        modelCatalogRefreshTask = task
        refreshMigrationWorkflowIdle()
        await task.value

        guard modelCatalogRefreshTaskID == taskID else { return }
        modelCatalogRefreshTask = nil
        modelCatalogRefreshTaskID = nil
        isRefreshingModelCatalog = false
        refreshMigrationWorkflowIdle()
        guard !isMigrationMaintenanceActive else { return }
        cachedProviderModels = Dictionary(
            uniqueKeysWithValues: LLMProviderPreset.all.compactMap { preset in
                guard let modelIDs = modelCatalogService.cachedModelIDs(for: preset.id) else {
                    return nil
                }
                return (preset.id, modelIDs)
            }
        )
    }

    func addPromptMode() {
        let mode = PromptMode(
            id: "custom-\(Int(Date().timeIntervalSince1970))",
            name: L10n.text("settings.mode.newName"),
            description: "",
            systemPrompt: "",
            shortcut: nil,
            participatesInAuto: false,
            autoRule: .none,
            sortOrder: (config.promptModes.map(\.sortOrder).max() ?? 0) + 1,
            isVisible: true
        )
        config.promptModes.append(mode)
        selectedPromptModeID = mode.id
        normalizePromptModeSortOrder()
        save()
    }

    func deleteSelectedPromptMode() {
        deletePromptMode(modeID: selectedPromptModeID)
    }

    func deletePromptMode(modeID: String) {
        guard config.promptModes.count > 1 else {
            message = L10n.text("settings.error.promptModeRequired")
            return
        }

        config.promptModes.removeAll { $0.id == modeID }
        normalizePromptModeSortOrder()

        if !config.promptModes.contains(where: \.isVisible),
           let firstIndex = config.promptModes.firstIndex(where: { _ in true }) {
            config.promptModes[firstIndex].isVisible = true
        }

        if selectedPromptModeID == modeID {
            selectedPromptModeID = config.promptModes.first?.id ?? PromptMode.translateToEnglishID
        }
        save()
    }

    func movePromptModes(from source: IndexSet, to destination: Int) {
        var orderedModes = orderedPromptModes
        orderedModes.move(fromOffsets: source, toOffset: destination)

        for (sortOrder, mode) in orderedModes.enumerated() {
            guard let configIndex = config.promptModes.firstIndex(where: { $0.id == mode.id }) else {
                continue
            }
            config.promptModes[configIndex].sortOrder = sortOrder
        }
        normalizePromptModeSortOrder()
        save()
    }

    func promptModeName(modeID: String) -> String {
        guard let mode = config.promptModes.first(where: { $0.id == modeID }) else {
            return L10n.text("settings.mode.untitled")
        }
        return mode.name.isEmpty ? L10n.text("settings.mode.untitled") : mode.localizedName
    }

    func togglePromptModeVisibility(modeID: String) {
        guard let index = config.promptModes.firstIndex(where: { $0.id == modeID }) else {
            return
        }

        if config.promptModes[index].isVisible,
           config.promptModes.filter(\.isVisible).count <= 1 {
            message = L10n.text("settings.error.visibleModeRequired")
            return
        }

        config.promptModes[index].isVisible.toggle()
        save()
    }

    func promptModeVisibilityBinding(modeID: String) -> Binding<Bool> {
        Binding(
            get: { [weak self] in
                self?.config.promptModes.first(where: { $0.id == modeID })?.isVisible ?? false
            },
            set: { [weak self] newValue in
                guard let self,
                      let mode = self.config.promptModes.first(where: { $0.id == modeID }),
                      mode.isVisible != newValue
                else {
                    return
                }
                self.togglePromptModeVisibility(modeID: modeID)
            }
        )
    }

    func canMovePromptMode(modeID: String, direction: Int) -> Bool {
        guard let currentIndex = orderedPromptModes.firstIndex(where: { $0.id == modeID }) else {
            return false
        }

        return orderedPromptModes.indices.contains(currentIndex + direction)
    }

    private func normalizePromptModeSortOrder() {
        let orderedModes = orderedPromptModes
        for (sortOrder, mode) in orderedModes.enumerated() {
            guard let index = config.promptModes.firstIndex(where: { $0.id == mode.id }) else {
                continue
            }
            config.promptModes[index].sortOrder = sortOrder
        }
        config.promptModes.sort { lhs, rhs in
            if lhs.sortOrder == rhs.sortOrder {
                return lhs.name < rhs.name
            }
            return lhs.sortOrder < rhs.sortOrder
        }
    }

    @discardableResult
    func save() -> Bool {
        guard !isMigrationMaintenanceActive else { return false }
        let trimmedKey = providerAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let shouldSaveConfig = config != savedConfig
        let shouldSaveProviderAPIKey = providerAPIKey != savedProviderAPIKey
        let shouldSaveInterfaceLanguage = interfaceLanguage != savedInterfaceLanguage
        guard shouldSaveConfig || shouldSaveProviderAPIKey || shouldSaveInterfaceLanguage else {
            return true
        }

        do {
            if shouldSaveConfig {
                guard config.promptModes.contains(where: \.isVisible) else {
                    message = L10n.text("settings.error.visibleModeRequired")
                    return false
                }
                guard !config.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    message = L10n.text("settings.error.modelRequired")
                    return false
                }
                config.providerID = LLMProviderPreset.openAI.id

                _ = try Hotkey.parse(config.hotkey)
                try configStore.save(config)
                savedConfig = config
            }

            if shouldSaveInterfaceLanguage {
                InkletLanguageStore.selectedLanguage = interfaceLanguage
                savedInterfaceLanguage = interfaceLanguage
            }

            if shouldSaveProviderAPIKey {
                if trimmedKey.isEmpty {
                    try apiKeyStore.deleteAPIKey(forProviderID: LLMProviderPreset.openAI.id)
                } else {
                    try apiKeyStore.saveAPIKey(trimmedKey, forProviderID: LLMProviderPreset.openAI.id)
                }
                providerAPIKey = trimmedKey
                savedProviderAPIKey = trimmedKey
            }
            message = L10n.text("settings.saved")
            NotificationCenter.default.post(name: .appConfigDidSave, object: nil)
            return true
        } catch let error as HotkeyError {
            message = error.userFacingMessage
            return false
        } catch {
            message = L10n.format("settings.error.saveFailed", String(describing: error))
            return false
        }
    }

    private func installAutoSave() {
        guard !isMigrationMaintenanceActive, autoSaveCancellable == nil else {
            return
        }
        autoSaveCancellable = Publishers.CombineLatest3($config, $providerAPIKey, $interfaceLanguage)
            .dropFirst()
            .debounce(for: .milliseconds(450), scheduler: RunLoop.main)
            .sink { [weak self] _, _, _ in
                guard let self else { return }
                self.save()
            }
    }

    func flushPendingEdits() -> Bool {
        autoSaveCancellable?.cancel()
        autoSaveCancellable = nil
        let didSave = hasPendingEdits ? save() : true
        installAutoSave()
        return didSave
    }

    private var hasPendingEdits: Bool {
        config != savedConfig
            || providerAPIKey != savedProviderAPIKey
            || interfaceLanguage != savedInterfaceLanguage
    }

    func setMigrationMaintenanceActive(_ isActive: Bool) {
        guard isMigrationMaintenanceActive != isActive else { return }
        isMigrationMaintenanceActive = isActive
        if isActive {
            autoSaveCancellable?.cancel()
            autoSaveCancellable = nil
            pronunciationPreviewTasks.values.forEach { $0.cancel() }
            modelCatalogRefreshTask?.cancel()
            pronunciationPreviewPlaybackService.stop()
            pronunciationPreviewState = nil
            refreshMigrationWorkflowIdle()
        } else {
            installAutoSave()
            refreshMigrationWorkflowIdle()
        }
    }

    func waitForMigrationMaintenanceQuiescence() async {
        let previewTasks = Array(pronunciationPreviewTasks.values)
        for task in previewTasks {
            await task.value
        }

        let catalogTaskID = modelCatalogRefreshTaskID
        await modelCatalogRefreshTask?.value
        if modelCatalogRefreshTaskID == catalogTaskID {
            modelCatalogRefreshTask = nil
            modelCatalogRefreshTaskID = nil
            isRefreshingModelCatalog = false
        }
        refreshMigrationWorkflowIdle()
    }

    private func refreshMigrationWorkflowIdle() {
        isMigrationWorkflowIdle = pronunciationPreviewState == nil
            && pronunciationPreviewTasks.isEmpty
            && modelCatalogRefreshTask == nil
            && !isRefreshingModelCatalog
    }

    func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else {
            message = L10n.text("settings.error.openAccessibility")
            return
        }

        NotificationCenter.default.post(
            name: .inkletDidOpenPermissionSettings,
            object: nil,
            userInfo: ["permission": PermissionSettingsDestination.accessibility.rawValue]
        )
        NSWorkspace.shared.open(url)
    }
}

extension Notification.Name {
    static let appConfigDidSave = Notification.Name("InkletAppConfigDidSave")
    static let hotkeyRecordingDidChange = Notification.Name("InkletHotkeyRecordingDidChange")
    static let inkletDidOpenPermissionSettings = Notification.Name("InkletDidOpenPermissionSettings")
    static let inkletAccessibilityDidBecomeTrusted = Notification.Name("InkletAccessibilityDidBecomeTrusted")
    static let inkletDidCompleteOnboarding = Notification.Name("InkletDidCompleteOnboarding")
}
