import AppKit
import Carbon
import Combine
import SwiftUI
import InkletCore

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var config: AppConfig
    @Published var message: String
    @Published var providerAPIKey: String
    @Published var voiceAPIKey: String
    @Published var selectedPromptModeID: String
    @Published var interfaceLanguage: InterfaceLanguage
    @Published var cachedProviderModels: [String: [String]]
    @Published var isRefreshingModelCatalog: Bool
    @Published var isEditingCustomModel: Bool
    @Published var isEditingCustomSpeechEndpoint: Bool
    @Published var isEditingCustomSpeechModel: Bool

    private let configStore: UserDefaultsConfigStore
    private let apiKeyStore: LocalAPIKeyStore
    private let modelCatalogService: ModelCatalogService
    private var cancellables = Set<AnyCancellable>()
    private var isLoadingProviderKey = false

    static let customModelMenuID = "__custom_model__"

    init(
        configStore: UserDefaultsConfigStore = UserDefaultsConfigStore(),
        apiKeyStore: LocalAPIKeyStore = LocalAPIKeyStore(),
        modelCatalogService: ModelCatalogService = ModelCatalogService()
    ) {
        var loadedConfig = (try? configStore.load()) ?? AppConfig.defaultConfig()
        loadedConfig.temperature = min(max(loadedConfig.temperature, 0), 1)
        self.configStore = configStore
        self.apiKeyStore = apiKeyStore
        self.modelCatalogService = modelCatalogService
        self.config = loadedConfig
        self.message = ""
        self.interfaceLanguage = InkletLanguageStore.selectedLanguage
        self.providerAPIKey = apiKeyStore.loadAPIKey(forProviderID: loadedConfig.providerID) ?? ""
        self.voiceAPIKey = apiKeyStore.loadAPIKey(forProviderID: VoiceInputConfig.openAISpeechProviderID) ?? ""
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
        self.isEditingCustomSpeechEndpoint = VoiceInputConfig.SpeechProfile.matching(
            endpoint: loadedConfig.voiceInput.speechEndpoint,
            model: loadedConfig.voiceInput.speechModel
        ) == .custom
        self.isEditingCustomSpeechModel = false

        installAutoSave()
    }

    var selectedProvider: LLMProviderPreset {
        config.resolvedProviderPreset
    }

    var isCustomOpenAICompatibleProvider: Bool {
        config.providerID == LLMProviderPreset.customOpenAICompatible.id
    }

    var selectedProviderModelOptions: [String] {
        guard !isCustomOpenAICompatibleProvider else {
            return []
        }

        var seen = Set<String>()
        var options: [String] = []

        for modelID in cachedProviderModels[config.providerID] ?? [] {
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

    var isInputMonitoringTrusted: Bool {
        InputMonitoringPermissionService().isTrusted
    }

    var speechModelOptions: [String] {
        var options = [
            VoiceInputConfig.defaultSpeechModel,
            "gpt-4o-transcribe",
            "whisper-1"
        ]
        let selectedModel = config.voiceInput.speechModel.trimmingCharacters(in: .whitespacesAndNewlines)
        if !selectedModel.isEmpty, !options.contains(selectedModel) {
            options.append(selectedModel)
        }
        return options
    }

    var selectedSpeechProfile: VoiceInputConfig.SpeechProfile {
        if isEditingCustomSpeechEndpoint {
            return .custom
        }

        return VoiceInputConfig.SpeechProfile.matching(
            endpoint: config.voiceInput.speechEndpoint,
            model: config.voiceInput.speechModel
        )
    }

    var selectedSpeechModelMenuValue: String {
        if isEditingCustomSpeechModel {
            return Self.customModelMenuID
        }

        return speechModelOptions.contains(config.voiceInput.speechModel)
            ? config.voiceInput.speechModel
            : Self.customModelMenuID
    }

    var shouldShowCustomSpeechEndpointField: Bool {
        isEditingCustomSpeechEndpoint || selectedSpeechProfile == .custom
    }

    var shouldShowCustomSpeechModelField: Bool {
        selectedSpeechProfile == .custom && selectedSpeechModelMenuValue == Self.customModelMenuID
    }

    var voiceCleanupModes: [PromptMode] {
        config.visiblePromptModes
    }

    func modelMenuTitle(for modelID: String) -> String {
        if modelID == config.model, !selectedModelIsDefault {
            return "\(modelID) *"
        }
        return modelID
    }

    func selectProvider(_ providerID: String) {
        config.providerID = providerID
        config.model = LLMProviderPreset.preset(id: providerID).defaultModel
        isLoadingProviderKey = true
        providerAPIKey = apiKeyStore.loadAPIKey(forProviderID: providerID) ?? ""
        isLoadingProviderKey = false
        isEditingCustomModel = false
        save()
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

    func selectSpeechProfile(_ profile: VoiceInputConfig.SpeechProfile) {
        guard profile != .custom else {
            isEditingCustomSpeechEndpoint = true
            return
        }
        guard let endpoint = profile.endpoint, let model = profile.model else {
            return
        }

        isEditingCustomSpeechEndpoint = false
        isEditingCustomSpeechModel = false
        config.voiceInput.speechEndpoint = endpoint
        config.voiceInput.speechModel = model
        save()
    }

    func selectSpeechModelMenuValue(_ value: String) {
        if value == Self.customModelMenuID {
            isEditingCustomSpeechEndpoint = true
            isEditingCustomSpeechModel = true
            return
        }

        isEditingCustomSpeechModel = false
        config.voiceInput.speechModel = value
        save()
    }

    func refreshModelCatalogIfNeeded() async {
        isRefreshingModelCatalog = true
        defer {
            isRefreshingModelCatalog = false
        }

        do {
            try await modelCatalogService.refreshIfNeeded()
            cachedProviderModels = Dictionary(
                uniqueKeysWithValues: LLMProviderPreset.all.compactMap { preset in
                    guard let modelIDs = modelCatalogService.cachedModelIDs(for: preset.id) else {
                        return nil
                    }
                    return (preset.id, modelIDs)
                }
            )
        } catch {
            // The model picker still works with saved/default/custom values when the catalog cannot be fetched.
        }
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

    func save() {
        do {
            guard config.promptModes.contains(where: \.isVisible) else {
                message = L10n.text("settings.error.visibleModeRequired")
                return
            }
            guard !config.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                message = L10n.text("settings.error.modelRequired")
                return
            }
            config.temperature = min(max(config.temperature, 0), 1)

            if isCustomOpenAICompatibleProvider {
                guard let endpoint = URL(string: config.customOpenAICompatibleEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)),
                      endpoint.scheme?.hasPrefix("http") == true,
                      endpoint.host != nil
                else {
                    message = L10n.text("settings.error.endpointInvalid")
                    return
                }
            }
            guard let speechEndpoint = URL(string: config.voiceInput.speechEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)),
                  speechEndpoint.scheme?.hasPrefix("http") == true,
                  speechEndpoint.host != nil
            else {
                message = L10n.text("voice.error.invalidSpeechEndpoint")
                return
            }

            _ = try Hotkey.parse(config.hotkey)
            InkletLanguageStore.selectedLanguage = interfaceLanguage
            try configStore.save(config)
            for provider in LLMProviderPreset.all {
                apiKeyStore.deleteAPIKey(forProviderID: provider.id)
            }
            let trimmedKey = providerAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedKey.isEmpty {
                apiKeyStore.saveAPIKey(trimmedKey, forProviderID: config.providerID)
            }
            apiKeyStore.deleteAPIKey(forProviderID: VoiceInputConfig.openAISpeechProviderID)
            let trimmedVoiceKey = voiceAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedVoiceKey.isEmpty {
                apiKeyStore.saveAPIKey(trimmedVoiceKey, forProviderID: VoiceInputConfig.openAISpeechProviderID)
            }
            message = L10n.text("settings.saved")
            NotificationCenter.default.post(name: .appConfigDidSave, object: nil)
        } catch let error as HotkeyError {
            message = error.userFacingMessage
        } catch {
            message = L10n.format("settings.error.saveFailed", String(describing: error))
        }
    }

    private func installAutoSave() {
        Publishers.CombineLatest4($config, $providerAPIKey, $voiceAPIKey, $interfaceLanguage)
            .dropFirst()
            .debounce(for: .milliseconds(450), scheduler: RunLoop.main)
            .sink { [weak self] _, _, _, _ in
                guard let self, !self.isLoadingProviderKey else {
                    return
                }
                self.save()
            }
            .store(in: &cancellables)
    }

    func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else {
            message = L10n.text("settings.error.openAccessibility")
            return
        }

        NSWorkspace.shared.open(url)
    }

    func openInputMonitoringSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        ) else {
            message = L10n.text("settings.error.openAccessibility")
            return
        }

        NSWorkspace.shared.open(url)
    }
}

extension Notification.Name {
    static let appConfigDidSave = Notification.Name("InkletAppConfigDidSave")
    static let hotkeyRecordingDidChange = Notification.Name("InkletHotkeyRecordingDidChange")
}

private extension PromptMode {
    static let builtInIDs: Set<String> = [
        PromptMode.translateToEnglishID,
        PromptMode.chineseSummaryID,
        PromptMode.voiceCleanupID
    ]
}

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General"
    case providers = "Providers"
    case voice = "Voice"
    case promptModes = "Prompt Modes"
    case permissions = "Permissions"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: L10n.text("settings.section.general")
        case .providers: L10n.text("settings.section.providers")
        case .voice: L10n.text("settings.section.voice")
        case .promptModes: L10n.text("settings.section.promptModes")
        case .permissions: L10n.text("settings.section.permissions")
        }
    }

    var icon: String {
        switch self {
        case .general: "gearshape"
        case .providers: "sparkles"
        case .voice: "mic"
        case .promptModes: "slider.horizontal.3"
        case .permissions: "lock.shield"
        }
    }
}

struct SettingsView: View {
    @StateObject private var model = SettingsViewModel()
    @State private var selectedSection: SettingsSection = .general
    @State private var promptModePendingDeletionID: String?

    private var isSavedMessage: Bool {
        model.message == L10n.text("settings.saved")
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            detail
        }
        .frame(width: 860, height: 560)
        .background(InkletTheme.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(InkletTheme.strongBorder)
        }
        .shadow(color: .black.opacity(0.75), radius: 48, x: 0, y: 28)
        .preferredColorScheme(model.config.appearance.colorScheme)
        .task {
            await model.refreshModelCatalogIfNeeded()
        }
        .alert(
            L10n.text("settings.mode.deleteConfirmTitle"),
            isPresented: Binding(
                get: { promptModePendingDeletionID != nil },
                set: { isPresented in
                    if !isPresented {
                        promptModePendingDeletionID = nil
                    }
                }
            )
        ) {
            Button(L10n.text("settings.mode.delete"), role: .destructive) {
                if let promptModePendingDeletionID {
                    model.deletePromptMode(modeID: promptModePendingDeletionID)
                }
                promptModePendingDeletionID = nil
            }
            Button(L10n.text("settings.cancel"), role: .cancel) {
                promptModePendingDeletionID = nil
            }
        } message: {
            Text(L10n.format("settings.mode.deleteConfirmMessage", model.promptModeName(modeID: promptModePendingDeletionID ?? "")))
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(InkletTheme.primary)
                        .frame(width: 28, height: 28)
                        .background(InkletTheme.primary.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(InkletTheme.primary.opacity(0.20))
                        }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Inklet")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(InkletTheme.textPrimary)
                        Text(L10n.text("settings.sidebar.preferences"))
                            .font(.system(size: 10))
                            .foregroundStyle(InkletTheme.textTertiary)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 2) {
                ForEach(SettingsSection.allCases) { section in
                    Button {
                        selectedSection = section
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: section.icon)
                                .frame(width: 18)
                            Text(section.title)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer()
                        }
                        .font(.system(size: 13, weight: selectedSection == section ? .semibold : .regular))
                        .foregroundStyle(selectedSection == section ? InkletTheme.primary.opacity(0.95) : InkletTheme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            selectedSection == section ? InkletTheme.primary.opacity(0.12) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)

            Spacer()
            Text(L10n.format("settings.version", "1.0.0"))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(InkletTheme.textFaint)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 188)
        .background(InkletTheme.toolbarBackground)
        .overlay(alignment: .trailing) { Rectangle().fill(InkletTheme.subtleBorder).frame(width: 1) }
    }

    private var detail: some View {
        VStack(spacing: 0) {
            detailHeader
            Divider().opacity(0.12)

            Group {
                switch selectedSection {
                case .general:
                    ScrollView {
                        generalPanel
                            .padding(.horizontal, 24)
                            .padding(.vertical, 20)
                    }
                case .providers:
                    providersPanel
                case .voice:
                    ScrollView {
                        voicePanel
                            .padding(.horizontal, 24)
                            .padding(.vertical, 20)
                    }
                case .promptModes:
                    promptModesPanel
                case .permissions:
                    ScrollView {
                        permissionsPanel
                            .padding(.horizontal, 24)
                            .padding(.vertical, 20)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider().opacity(0.12)
            footer
        }
    }

    private var detailHeader: some View {
        HStack {
            Text(selectedSection.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(InkletTheme.textPrimary)
            Spacer()
            Button {
                NSApp.keyWindow?.close()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(InkletTheme.textSecondary)
                    .frame(width: 26, height: 26)
                    .background(Color.white.opacity(0.001), in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 15)
    }

    private var sectionDescription: String {
        switch selectedSection {
        case .general:
            L10n.text("settings.description.general")
        case .providers:
            L10n.text("settings.description.providers")
        case .voice:
            L10n.text("settings.description.voice")
        case .promptModes:
            L10n.text("settings.description.promptModes")
        case .permissions:
            L10n.text("settings.description.permissions")
        }
    }

    private var generalPanel: some View {
        settingsPanel {
            settingsRow(L10n.text("settings.row.language"), help: L10n.text("settings.help.language")) {
                Picker("", selection: $model.interfaceLanguage) {
                    ForEach(InterfaceLanguage.allCases) { language in
                        Text(language.localizedDisplayName).tag(language)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 320, alignment: .leading)
            }

            settingsRow(L10n.text("settings.row.appearance"), help: L10n.text("settings.help.appearance")) {
                Picker("", selection: $model.config.appearance) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(appearance.localizedDisplayName).tag(appearance)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 320, alignment: .leading)
            }

            settingsRow(L10n.text("settings.row.hotkey"), help: L10n.text("settings.help.hotkey")) {
                HotkeyRecorderField(hotkey: $model.config.hotkey)
                    .frame(width: 220, height: 34)
            }

            settingsRow(L10n.text("settings.row.temperature"), help: L10n.text("settings.help.temperature")) {
                HStack(spacing: 12) {
                    Slider(value: $model.config.temperature, in: 0...1, step: 0.1)
                    Text(model.config.temperature, format: .number.precision(.fractionLength(1)))
                        .font(.body.monospacedDigit())
                        .frame(width: 42, alignment: .trailing)
                }
                .frame(maxWidth: 520)
            }

            settingsRow(L10n.text("settings.row.timeout"), help: L10n.text("settings.help.timeout")) {
                Stepper(value: $model.config.timeoutSeconds, in: 1...120, step: 1) {
                    Text(L10n.format("settings.seconds", Int(model.config.timeoutSeconds)))
                        .font(.body.monospacedDigit())
                }
            }
        }
    }

    private var providersPanel: some View {
        let selectedModelBinding = Binding(
            get: { model.selectedModelMenuValue },
            set: { model.selectModelMenuValue($0) }
        )
        let selectedProviderBinding = Binding(
            get: { model.config.providerID },
            set: { model.selectProvider($0) }
        )

        return
            ScrollView {
                settingsPanel {
                    settingsRow("Provider", help: "Choose the single provider Inklet will use for every transform.") {
                        Picker("", selection: selectedProviderBinding) {
                            ForEach(LLMProviderPreset.all) { provider in
                                Text(provider.name).tag(provider.id)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 320, alignment: .leading)
                    }

                    settingsRow(L10n.text("settings.row.apiKey"), help: L10n.text("settings.help.apiKey")) {
                        SecureField(model.selectedProvider.apiKeyPlaceholder, text: $model.providerAPIKey)
                            .textFieldStyle(.roundedBorder)
                    }

                    if model.isCustomOpenAICompatibleProvider {
                        settingsRow(L10n.text("settings.row.endpoint"), help: L10n.text("settings.help.endpoint")) {
                            TextField(
                                LLMProviderPreset.customOpenAICompatible.endpoint.absoluteString,
                                text: $model.config.customOpenAICompatibleEndpoint
                            )
                            .textFieldStyle(.roundedBorder)
                        }
                    }

                    settingsRow(L10n.text("settings.row.model"), help: L10n.format("settings.help.model.default", model.selectedProvider.defaultModel)) {
                        VStack(alignment: .leading, spacing: 8) {
                            if !model.selectedProviderModelOptions.isEmpty {
                                Picker("", selection: selectedModelBinding) {
                                    ForEach(model.selectedProviderModelOptions, id: \.self) { modelID in
                                        Text(model.modelMenuTitle(for: modelID)).tag(modelID)
                                    }
                                    Divider()
                                    Text(L10n.text("settings.model.custom")).tag(SettingsViewModel.customModelMenuID)
                                }
                                .labelsHidden()
                                .frame(maxWidth: 320, alignment: .leading)
                            }

                            if model.shouldShowCustomModelField {
                                VStack(alignment: .leading, spacing: 6) {
                                    TextField(model.selectedProvider.defaultModel, text: $model.config.model)
                                        .textFieldStyle(.roundedBorder)
                                    if !model.selectedModelIsDefault {
                                        Text(L10n.text("settings.model.customized"))
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(InkletTheme.primary)
                                    }
                                }
                            }

                            if model.isRefreshingModelCatalog {
                                Text(L10n.text("settings.model.refreshing"))
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
    }

    private var voicePanel: some View {
        let selectedSpeechProfileBinding = Binding(
            get: { model.selectedSpeechProfile },
            set: { model.selectSpeechProfile($0) }
        )
        let selectedSpeechModelBinding = Binding(
            get: { model.selectedSpeechModelMenuValue },
            set: { model.selectSpeechModelMenuValue($0) }
        )

        return settingsPanel {
            settingsRow(L10n.text("settings.row.voiceShortcut"), help: L10n.text("settings.help.voiceShortcut")) {
                Picker("", selection: $model.config.voiceInput.shortcut) {
                    ForEach(VoiceInputConfig.Shortcut.allCases) { shortcut in
                        Text(shortcut.localizedName).tag(shortcut)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 320, alignment: .leading)
            }

            settingsRow(L10n.text("settings.row.speechAPIKey"), help: L10n.text("settings.help.speechAPIKey")) {
                SecureField("sk-...", text: $model.voiceAPIKey)
                    .textFieldStyle(.roundedBorder)
            }

            settingsRow(L10n.text("settings.row.speechProfile"), help: L10n.text("settings.help.speechProfile")) {
                Picker("", selection: selectedSpeechProfileBinding) {
                    ForEach(VoiceInputConfig.SpeechProfile.allCases) { profile in
                        Text(profile.localizedName).tag(profile)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 320, alignment: .leading)
            }

            if model.shouldShowCustomSpeechEndpointField {
                settingsRow(L10n.text("settings.row.speechEndpoint"), help: L10n.text("settings.help.speechEndpoint")) {
                    TextField(VoiceInputConfig.defaultSpeechEndpoint, text: $model.config.voiceInput.speechEndpoint)
                        .textFieldStyle(.roundedBorder)
                }
            }

            settingsRow(
                L10n.text("settings.row.speechModel"),
                help: L10n.format("settings.help.speechModel", VoiceInputConfig.defaultSpeechModel)
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("", selection: selectedSpeechModelBinding) {
                        ForEach(model.speechModelOptions, id: \.self) { modelID in
                            Text(modelID).tag(modelID)
                        }
                        Divider()
                        Text(L10n.text("settings.model.custom")).tag(SettingsViewModel.customModelMenuID)
                    }
                    .labelsHidden()
                    .frame(maxWidth: 320, alignment: .leading)

                    if model.shouldShowCustomSpeechModelField {
                        TextField(VoiceInputConfig.defaultSpeechModel, text: $model.config.voiceInput.speechModel)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }

            settingsRow(L10n.text("settings.row.voiceAutoProcess"), help: L10n.text("settings.help.voiceAutoProcess")) {
                Toggle("", isOn: $model.config.voiceInput.autoProcessTranscription)
                    .labelsHidden()
            }

            settingsRow(L10n.text("settings.row.voiceCleanupMode"), help: L10n.text("settings.help.voiceCleanupMode")) {
                Picker("", selection: $model.config.voiceInput.voiceCleanupPromptModeID) {
                    ForEach(model.voiceCleanupModes) { mode in
                        Text(mode.localizedName).tag(mode.id)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 320, alignment: .leading)
                .disabled(!model.config.voiceInput.autoProcessTranscription)
            }
        }
    }

    private var promptModesPanel: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 0) {
                PromptModeTableView(
                    modes: model.orderedPromptModes,
                    selectedModeID: $model.selectedPromptModeID,
                    canDelete: model.config.promptModes.count > 1,
                    onMove: { source, destination in
                        model.movePromptModes(from: IndexSet(integer: source), to: destination)
                    },
                    onToggleVisibility: { modeID in
                        model.togglePromptModeVisibility(modeID: modeID)
                    },
                    onDelete: { modeID in
                        promptModePendingDeletionID = modeID
                    }
                )
                .padding(.top, 10)
                .frame(maxWidth: .infinity)
                .background(InkletTheme.toolbarBackground)
                Divider().opacity(0.12)
                Button {
                    model.addPromptMode()
                } label: {
                    Label(L10n.text("settings.mode.add"), systemImage: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(InkletTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(InkletTheme.controlFill, in: RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                                .foregroundStyle(InkletTheme.subtleBorder)
                        }
                }
                .buttonStyle(.plain)
                .padding(10)
                .frame(width: 236)
            }
            .frame(minWidth: 236, idealWidth: 236, maxWidth: 236, maxHeight: .infinity, alignment: .top)
            .fixedSize(horizontal: true, vertical: false)
            .clipped()
            .overlay(alignment: .trailing) { Rectangle().fill(InkletTheme.subtleBorder).frame(width: 1) }

            if let index = model.selectedPromptModeIndex {
                ScrollView {
                    promptModeDetail(index: index)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)
            } else {
                Text(L10n.text("settings.mode.pick"))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 280)
            }
        }
    }

    private func promptModeDetail(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 11) {
                settingsRow(L10n.text("settings.row.name"), help: L10n.text("settings.help.name")) {
                    TextField(L10n.text("settings.row.name"), text: $model.config.promptModes[index].name)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .modifier(InkletFieldModifier())
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.text("settings.row.systemPrompt"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(InkletTheme.textPrimary)

                SettingsPromptTextView(text: $model.config.promptModes[index].systemPrompt)
                    .frame(height: 164)
                    .padding(10)
                    .modifier(InkletFieldModifier())
            }

            settingsToggle(
                title: L10n.text("settings.mode.visibleInMenu"),
                subtitle: L10n.text("settings.mode.visibleInMenuHelp"),
                isOn: model.promptModeVisibilityBinding(modeID: model.config.promptModes[index].id)
            )
            .padding(.top, 2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
    }

    private var permissionsPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: model.isAccessibilityTrusted ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(model.isAccessibilityTrusted ? InkletTheme.success : InkletTheme.warning)
                        .frame(width: 40, height: 40)
                        .background((model.isAccessibilityTrusted ? InkletTheme.success : InkletTheme.warning).opacity(0.18), in: RoundedRectangle(cornerRadius: 9))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.text("settings.permission.accessibility"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(InkletTheme.textPrimary)
                        Text(L10n.text("settings.permission.description"))
                            .font(.system(size: 12))
                            .foregroundStyle(InkletTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Text(model.isAccessibilityTrusted ? L10n.text("settings.permission.authorized") : L10n.text("settings.permission.required"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(model.isAccessibilityTrusted ? InkletTheme.success : InkletTheme.warning)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background((model.isAccessibilityTrusted ? InkletTheme.success : InkletTheme.warning).opacity(0.16), in: RoundedRectangle(cornerRadius: 6))
                }

                Button {
                    model.openAccessibilitySettings()
                } label: {
                    Label(L10n.text("settings.permission.open"), systemImage: "arrow.up.forward.app")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(16)
            .background(InkletTheme.controlFill, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(InkletTheme.subtleBorder)
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: model.isInputMonitoringTrusted ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(model.isInputMonitoringTrusted ? InkletTheme.success : InkletTheme.warning)
                        .frame(width: 40, height: 40)
                        .background((model.isInputMonitoringTrusted ? InkletTheme.success : InkletTheme.warning).opacity(0.18), in: RoundedRectangle(cornerRadius: 9))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.text("settings.permission.inputMonitoring"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(InkletTheme.textPrimary)
                        Text(L10n.text("settings.permission.inputMonitoringDescription"))
                            .font(.system(size: 12))
                            .foregroundStyle(InkletTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Text(model.isInputMonitoringTrusted ? L10n.text("settings.permission.inputMonitoringAuthorized") : L10n.text("settings.permission.inputMonitoringRequired"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(model.isInputMonitoringTrusted ? InkletTheme.success : InkletTheme.warning)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background((model.isInputMonitoringTrusted ? InkletTheme.success : InkletTheme.warning).opacity(0.16), in: RoundedRectangle(cornerRadius: 6))
                }

                Button {
                    model.openInputMonitoringSettings()
                } label: {
                    Label(L10n.text("settings.permission.open"), systemImage: "arrow.up.forward.app")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(16)
            .background(InkletTheme.controlFill, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(InkletTheme.subtleBorder)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.text("settings.privacy.title"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(InkletTheme.textPrimary)
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.text("settings.privacy.keychain"))
                    Text(L10n.text("settings.privacy.provider"))
                    Text(L10n.text("settings.privacy.voice"))
                    Text(L10n.text("settings.privacy.clipboard"))
                }
                .font(.system(size: 12))
                .foregroundStyle(InkletTheme.textSecondary)
            }
            .padding(16)
            .background(InkletTheme.controlFill, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(InkletTheme.subtleBorder)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if !model.message.isEmpty {
                Label(model.message, systemImage: isSavedMessage ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(isSavedMessage ? InkletTheme.success : .red)
                    .lineLimit(2)
            } else {
                Text(L10n.text("settings.footer.pending"))
                    .font(.footnote)
                    .foregroundStyle(InkletTheme.textFaint)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(InkletTheme.toolbarBackground)
    }

    private func settingsPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(0)
        .frame(maxWidth: 580, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func settingsRow<Content: View>(
        _ title: String,
        help: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(InkletTheme.textPrimary)
                Spacer()
            }
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
            if !help.isEmpty {
                Text(help)
                    .font(.system(size: 11))
                    .foregroundStyle(InkletTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func settingsToggle(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(InkletTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(InkletTheme.textSecondary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }
}

private struct PromptModeTableView: NSViewRepresentable {
    let modes: [PromptMode]
    @Binding var selectedModeID: String
    let canDelete: Bool
    let onMove: (Int, Int) -> Void
    let onToggleVisibility: (String) -> Void
    let onDelete: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            modes: modes,
            selectedModeID: $selectedModeID,
            canDelete: canDelete,
            onMove: onMove,
            onToggleVisibility: onToggleVisibility,
            onDelete: onDelete
        )
    }

    func makeNSView(context: Context) -> NSScrollView {
        let tableView = NSTableView()
        let column = NSTableColumn(identifier: Coordinator.columnIdentifier)
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 38
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .none
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.delegate = context.coordinator
        tableView.dataSource = context.coordinator
        tableView.registerForDraggedTypes([Coordinator.dragPasteboardType])

        let scrollView = PromptModeTableScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.horizontalScrollElasticity = .none
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.documentView = tableView
        context.coordinator.tableView = tableView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.modes = modes
        context.coordinator.selectedModeID = $selectedModeID
        context.coordinator.canDelete = canDelete
        context.coordinator.onMove = onMove
        context.coordinator.onToggleVisibility = onToggleVisibility
        context.coordinator.onDelete = onDelete

        guard let tableView = scrollView.documentView as? NSTableView else {
            return
        }

        PromptModeTableScrollView.syncTableWidth(tableView, to: scrollView.contentView.bounds.width)

        tableView.reloadData()
        context.coordinator.syncSelection()
    }

    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        static let columnIdentifier = NSUserInterfaceItemIdentifier("PromptModeColumn")
        static let rowIdentifier = NSUserInterfaceItemIdentifier("PromptModeRow")
        static let dragPasteboardType = NSPasteboard.PasteboardType("com.inklet.prompt-mode")

        var modes: [PromptMode]
        var selectedModeID: Binding<String>
        var canDelete: Bool
        var onMove: (Int, Int) -> Void
        var onToggleVisibility: (String) -> Void
        var onDelete: (String) -> Void
        weak var tableView: NSTableView?
        private var isSyncingSelection = false

        init(
            modes: [PromptMode],
            selectedModeID: Binding<String>,
            canDelete: Bool,
            onMove: @escaping (Int, Int) -> Void,
            onToggleVisibility: @escaping (String) -> Void,
            onDelete: @escaping (String) -> Void
        ) {
            self.modes = modes
            self.selectedModeID = selectedModeID
            self.canDelete = canDelete
            self.onMove = onMove
            self.onToggleVisibility = onToggleVisibility
            self.onDelete = onDelete
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            modes.count
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard modes.indices.contains(row) else {
                return nil
            }

            let cell = (tableView.makeView(withIdentifier: Self.rowIdentifier, owner: self) as? PromptModeTableCellView)
                ?? PromptModeTableCellView(identifier: Self.rowIdentifier)
            let mode = modes[row]
            cell.configure(
                mode: mode,
                isSelected: mode.id == selectedModeID.wrappedValue,
                canDelete: canDelete,
                target: self
            )
            return cell
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            guard !isSyncingSelection,
                  let tableView,
                  modes.indices.contains(tableView.selectedRow)
            else {
                return
            }

            selectedModeID.wrappedValue = modes[tableView.selectedRow].id
        }

        func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
            guard modes.indices.contains(row) else {
                return nil
            }

            let item = NSPasteboardItem()
            item.setString(modes[row].id, forType: Self.dragPasteboardType)
            return item
        }

        func tableView(
            _ tableView: NSTableView,
            validateDrop info: NSDraggingInfo,
            proposedRow row: Int,
            proposedDropOperation dropOperation: NSTableView.DropOperation
        ) -> NSDragOperation {
            tableView.setDropRow(row, dropOperation: .above)
            return .move
        }

        func tableView(
            _ tableView: NSTableView,
            acceptDrop info: NSDraggingInfo,
            row: Int,
            dropOperation: NSTableView.DropOperation
        ) -> Bool {
            guard let draggedModeID = info.draggingPasteboard.string(forType: Self.dragPasteboardType),
                  let sourceIndex = modes.firstIndex(where: { $0.id == draggedModeID })
            else {
                return false
            }

            let destination = max(0, min(row, modes.count))
            guard sourceIndex != destination, sourceIndex + 1 != destination else {
                return false
            }

            onMove(sourceIndex, destination)
            selectedModeID.wrappedValue = draggedModeID
            return true
        }

        @MainActor
        func syncSelection() {
            guard let tableView else {
                return
            }

            isSyncingSelection = true
            defer { isSyncingSelection = false }

            if let selectedIndex = modes.firstIndex(where: { $0.id == selectedModeID.wrappedValue }) {
                tableView.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
            } else {
                tableView.deselectAll(nil)
            }
        }

        @MainActor
        @objc func toggleVisibility(_ sender: NSButton) {
            guard let modeID = sender.identifier?.rawValue else {
                return
            }
            onToggleVisibility(modeID)
        }

        @MainActor
        @objc func deleteMode(_ sender: NSButton) {
            guard let modeID = sender.identifier?.rawValue else {
                return
            }
            onDelete(modeID)
        }
    }
}

private final class PromptModeTableScrollView: NSScrollView {
    override func layout() {
        super.layout()
        guard let tableView = documentView as? NSTableView else {
            return
        }
        Self.syncTableWidth(tableView, to: contentView.bounds.width)
    }

    static func syncTableWidth(_ tableView: NSTableView, to width: CGFloat) {
        let width = max(width, 1)
        guard tableView.tableColumns.first?.width != width else {
            return
        }

        tableView.tableColumns.first?.width = width
        var frame = tableView.frame
        frame.size.width = width
        tableView.frame = frame
    }
}

private final class PromptModeTableCellView: NSTableCellView {
    private static let rowWidth: CGFloat = 190
    private let rowContainer = NSView()
    private let selectionBackground = NSView()
    private let dragHandle = NSImageView()
    private let titleField = NSTextField(labelWithString: "")
    private let visibilityButton = NSButton()
    private let deleteButton = NSButton()
    private var trackingArea: NSTrackingArea?
    private var isHovered = false
    private var isCellSelected = false
    private var isModeVisible = true
    private var canDeleteMode = true

    init(identifier: NSUserInterfaceItemIdentifier) {
        super.init(frame: .zero)
        self.identifier = identifier
        buildView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        mode: PromptMode,
        isSelected: Bool,
        canDelete: Bool,
        target: PromptModeTableView.Coordinator
    ) {
        let symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        isCellSelected = isSelected
        isModeVisible = mode.isVisible
        canDeleteMode = canDelete
        titleField.stringValue = mode.name.isEmpty ? L10n.text("settings.mode.untitled") : mode.localizedName
        titleField.font = .systemFont(ofSize: 13, weight: isSelected ? .semibold : .regular)
        visibilityButton.image = NSImage(systemSymbolName: mode.isVisible ? "eye" : "eye.slash", accessibilityDescription: nil)?
            .withSymbolConfiguration(symbolConfiguration)
        visibilityButton.toolTip = mode.isVisible ? L10n.text("settings.mode.visible") : L10n.text("settings.mode.hidden")
        visibilityButton.identifier = NSUserInterfaceItemIdentifier(mode.id)
        visibilityButton.target = target
        visibilityButton.action = #selector(PromptModeTableView.Coordinator.toggleVisibility(_:))

        deleteButton.identifier = NSUserInterfaceItemIdentifier(mode.id)
        deleteButton.target = target
        deleteButton.action = #selector(PromptModeTableView.Coordinator.deleteMode(_:))
        deleteButton.isEnabled = canDelete
        deleteButton.toolTip = L10n.text("settings.mode.delete")
        applyAppearance()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self
        )
        trackingArea = area
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        applyAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        applyAppearance()
    }

    private func buildView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        rowContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rowContainer)

        selectionBackground.wantsLayer = true
        selectionBackground.layer?.cornerRadius = 12
        selectionBackground.layer?.cornerCurve = .continuous
        selectionBackground.layer?.backgroundColor = NSColor.clear.cgColor
        selectionBackground.translatesAutoresizingMaskIntoConstraints = false
        rowContainer.addSubview(selectionBackground)

        let symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        dragHandle.image = NSImage(systemSymbolName: "line.3.horizontal", accessibilityDescription: nil)?
            .withSymbolConfiguration(symbolConfiguration)
        dragHandle.contentTintColor = NSColor(white: 1, alpha: 0.18)
        dragHandle.setContentHuggingPriority(.required, for: .horizontal)
        dragHandle.setContentCompressionResistancePriority(.required, for: .horizontal)
        dragHandle.toolTip = L10n.text("settings.mode.dragToSort")
        dragHandle.translatesAutoresizingMaskIntoConstraints = false

        titleField.lineBreakMode = .byTruncatingTail
        titleField.textColor = NSColor(white: 0.74, alpha: 1)
        titleField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        titleField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleField.translatesAutoresizingMaskIntoConstraints = false

        configureIconButton(visibilityButton)
        configureIconButton(deleteButton)
        deleteButton.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)?
            .withSymbolConfiguration(symbolConfiguration)
        deleteButton.contentTintColor = NSColor(white: 1, alpha: 0.32)

        rowContainer.addSubview(dragHandle)
        rowContainer.addSubview(titleField)
        rowContainer.addSubview(visibilityButton)
        rowContainer.addSubview(deleteButton)

        NSLayoutConstraint.activate([
            rowContainer.widthAnchor.constraint(equalToConstant: Self.rowWidth),
            rowContainer.centerXAnchor.constraint(equalTo: centerXAnchor, constant: -16),
            rowContainer.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            rowContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
            selectionBackground.leadingAnchor.constraint(equalTo: rowContainer.leadingAnchor),
            selectionBackground.trailingAnchor.constraint(equalTo: rowContainer.trailingAnchor),
            selectionBackground.topAnchor.constraint(equalTo: rowContainer.topAnchor),
            selectionBackground.bottomAnchor.constraint(equalTo: rowContainer.bottomAnchor),
            dragHandle.widthAnchor.constraint(equalToConstant: 18),
            visibilityButton.widthAnchor.constraint(equalToConstant: 24),
            visibilityButton.heightAnchor.constraint(equalToConstant: 24),
            deleteButton.widthAnchor.constraint(equalToConstant: 24),
            deleteButton.heightAnchor.constraint(equalToConstant: 24),
            dragHandle.leadingAnchor.constraint(equalTo: rowContainer.leadingAnchor, constant: 14),
            dragHandle.centerYAnchor.constraint(equalTo: rowContainer.centerYAnchor),
            titleField.leadingAnchor.constraint(equalTo: dragHandle.trailingAnchor, constant: 10),
            titleField.trailingAnchor.constraint(equalTo: visibilityButton.leadingAnchor, constant: -8),
            titleField.centerYAnchor.constraint(equalTo: rowContainer.centerYAnchor),
            visibilityButton.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -4),
            visibilityButton.centerYAnchor.constraint(equalTo: rowContainer.centerYAnchor),
            deleteButton.trailingAnchor.constraint(equalTo: rowContainer.trailingAnchor, constant: -10),
            deleteButton.centerYAnchor.constraint(equalTo: rowContainer.centerYAnchor)
        ])
    }

    private func applyAppearance() {
        let isDark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        selectionBackground.layer?.backgroundColor = isCellSelected
            ? NSColor.controlAccentColor.withAlphaComponent(isDark ? 0.20 : 0.14).cgColor
            : (isHovered ? NSColor.labelColor.withAlphaComponent(isDark ? 0.04 : 0.045).cgColor : NSColor.clear.cgColor)
        titleField.textColor = isCellSelected
            ? NSColor.controlAccentColor
            : (isHovered ? .labelColor : .secondaryLabelColor)
        dragHandle.contentTintColor = isHovered || isCellSelected
            ? .secondaryLabelColor
            : .tertiaryLabelColor
        visibilityButton.contentTintColor = isModeVisible
            ? .secondaryLabelColor
            : .tertiaryLabelColor
        visibilityButton.alphaValue = isHovered || isCellSelected ? 1 : 0.78
        deleteButton.contentTintColor = canDeleteMode
            ? .secondaryLabelColor
            : .tertiaryLabelColor
        deleteButton.alphaValue = isHovered || isCellSelected ? 1 : 0.64
    }

    private func configureIconButton(_ button: NSButton) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.setButtonType(.momentaryChange)
        button.imagePosition = .imageOnly
        button.focusRingType = .none
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
    }
}

private struct SettingsPromptTextView: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.contentInsets = NSEdgeInsetsZero
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.horizontalScrollElasticity = .none

        let textView = NSTextView()
        textView.string = text
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesFindBar = false
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.font = .systemFont(ofSize: 13)
        textView.textColor = .labelColor
        textView.insertionPointColor = .controlAccentColor
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]

        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else {
            return
        }

        context.coordinator.text = $text
        context.coordinator.textView = textView
        textView.font = .systemFont(ofSize: 13)
        textView.textColor = .labelColor
        textView.insertionPointColor = .controlAccentColor

        if !textView.hasMarkedText(), textView.string != text {
            textView.string = text
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate, @unchecked Sendable {
        var text: Binding<String>
        weak var textView: NSTextView?

        init(text: Binding<String>) {
            self.text = text
            super.init()
        }

        @MainActor
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }

            text.wrappedValue = textView.string
        }
    }
}

private struct HotkeyRecorderField: NSViewRepresentable {
    @Binding var hotkey: String

    func makeCoordinator() -> Coordinator {
        Coordinator(hotkey: $hotkey)
    }

    func makeNSView(context: Context) -> RecorderView {
        let view = RecorderView()
        view.onChange = { context.coordinator.hotkey.wrappedValue = $0 }
        view.hotkey = hotkey
        return view
    }

    func updateNSView(_ nsView: RecorderView, context: Context) {
        nsView.hotkey = hotkey
        nsView.onChange = { context.coordinator.hotkey.wrappedValue = $0 }
        nsView.updateDisplay()
    }

    final class Coordinator {
        var hotkey: Binding<String>

        init(hotkey: Binding<String>) {
            self.hotkey = hotkey
        }
    }

    final class RecorderView: NSView {
        var hotkey = ""
        var onChange: ((String) -> Void)?
        private var isRecording = false
        private let label = NSTextField(labelWithString: "")

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            layer?.cornerRadius = 8
            layer?.borderWidth = 1
            label.translatesAutoresizingMaskIntoConstraints = false
            label.alignment = .center
            label.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
            addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
                label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
                label.centerYAnchor.constraint(equalTo: centerYAnchor)
            ])
            updateDisplay()
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override var acceptsFirstResponder: Bool { true }

        override func mouseDown(with event: NSEvent) {
            isRecording = true
            publishRecordingState()
            window?.makeFirstResponder(self)
            updateDisplay()
        }

        override func resignFirstResponder() -> Bool {
            isRecording = false
            publishRecordingState()
            updateDisplay()
            return super.resignFirstResponder()
        }

        override func keyDown(with event: NSEvent) {
            guard isRecording else {
                super.keyDown(with: event)
                return
            }

            if event.keyCode == UInt16(kVK_Escape) {
                isRecording = false
                publishRecordingState()
                window?.makeFirstResponder(nil)
                updateDisplay()
                return
            }

            guard let recordedHotkey = recordedHotkey(from: event) else {
                NSSound.beep()
                return
            }

            hotkey = recordedHotkey.displayString
            onChange?(hotkey)
            isRecording = false
            publishRecordingState()
            window?.makeFirstResponder(nil)
            updateDisplay()
        }

        override func flagsChanged(with event: NSEvent) {
            if isRecording {
                updateDisplay(pressedModifiers: modifierDisplayString(from: event.modifierFlags))
            } else {
                super.flagsChanged(with: event)
            }
        }

        func updateDisplay(pressedModifiers: String = "") {
            let backgroundColor = isRecording ? NSColor.controlAccentColor.withAlphaComponent(0.16) : NSColor.controlBackgroundColor
            layer?.backgroundColor = backgroundColor.cgColor
            layer?.borderColor = (isRecording ? NSColor.controlAccentColor : NSColor.separatorColor).cgColor
            label.textColor = isRecording ? .controlAccentColor : .labelColor
            if isRecording {
                label.stringValue = pressedModifiers.isEmpty
                    ? L10n.text("settings.hotkey.recording")
                    : "\(pressedModifiers)\(L10n.text("settings.hotkey.pressKey"))"
            } else {
                label.stringValue = hotkey.isEmpty ? L10n.text("settings.hotkey.record") : hotkey
            }
        }

        private func recordedHotkey(from event: NSEvent) -> Hotkey? {
            var modifiers: Hotkey.Modifier = []
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags.contains(.command) { modifiers.insert(.command) }
            if flags.contains(.option) { modifiers.insert(.option) }
            if flags.contains(.control) { modifiers.insert(.control) }
            if flags.contains(.shift) { modifiers.insert(.shift) }

            guard !modifiers.isEmpty,
                  modifiers != [.shift],
                  Hotkey.displayName(for: UInt32(event.keyCode)) != nil
            else {
                return nil
            }

            return Hotkey(keyCode: UInt32(event.keyCode), modifiers: modifiers)
        }

        private func modifierDisplayString(from flags: NSEvent.ModifierFlags) -> String {
            var modifiers: Hotkey.Modifier = []
            let filteredFlags = flags.intersection(.deviceIndependentFlagsMask)
            if filteredFlags.contains(.command) { modifiers.insert(.command) }
            if filteredFlags.contains(.option) { modifiers.insert(.option) }
            if filteredFlags.contains(.control) { modifiers.insert(.control) }
            if filteredFlags.contains(.shift) { modifiers.insert(.shift) }
            return modifiers.displayString
        }

        private func publishRecordingState() {
            NotificationCenter.default.post(
                name: .hotkeyRecordingDidChange,
                object: nil,
                userInfo: ["isRecording": isRecording]
            )
        }
    }
}
