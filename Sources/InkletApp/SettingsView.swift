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
    @Published var selectedPromptModeID: String
    @Published var interfaceLanguage: InterfaceLanguage
    @Published var cachedProviderModels: [String: [String]]
    @Published var isRefreshingModelCatalog: Bool
    @Published var isEditingCustomModel: Bool

    private let configStore: UserDefaultsConfigStore
    private let apiKeyStore: LocalAPIKeyStore
    private let modelCatalogService: ModelCatalogService

    static let customModelMenuID = "__custom_model__"

    init(
        configStore: UserDefaultsConfigStore = UserDefaultsConfigStore(),
        apiKeyStore: LocalAPIKeyStore = LocalAPIKeyStore(),
        modelCatalogService: ModelCatalogService = ModelCatalogService()
    ) {
        let loadedConfig = (try? configStore.load()) ?? AppConfig.defaultConfig()
        self.configStore = configStore
        self.apiKeyStore = apiKeyStore
        self.modelCatalogService = modelCatalogService
        self.config = loadedConfig
        self.message = ""
        self.interfaceLanguage = InkletLanguageStore.selectedLanguage
        self.providerAPIKey = apiKeyStore.loadAPIKey(forProviderID: loadedConfig.providerID) ?? ""
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

    func modelMenuTitle(for modelID: String) -> String {
        if modelID == config.model, !selectedModelIsDefault {
            return "\(modelID) *"
        }
        return modelID
    }

    func selectProvider(_ providerID: String) {
        config.providerID = providerID
        config.model = LLMProviderPreset.preset(id: providerID).defaultModel
        providerAPIKey = apiKeyStore.loadAPIKey(forProviderID: providerID) ?? ""
        isEditingCustomModel = false
    }

    func selectModelMenuValue(_ value: String) {
        if value == Self.customModelMenuID {
            isEditingCustomModel = true
            return
        }

        isEditingCustomModel = false
        config.model = value
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
            description: L10n.text("settings.mode.newDescription"),
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

            if isCustomOpenAICompatibleProvider {
                guard let endpoint = URL(string: config.customOpenAICompatibleEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)),
                      endpoint.scheme?.hasPrefix("http") == true,
                      endpoint.host != nil
                else {
                    message = L10n.text("settings.error.endpointInvalid")
                    return
                }
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
            message = L10n.text("settings.saved")
            NotificationCenter.default.post(name: .appConfigDidSave, object: nil)
        } catch let error as HotkeyError {
            message = error.userFacingMessage
        } catch {
            message = L10n.format("settings.error.saveFailed", String(describing: error))
        }
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
}

extension Notification.Name {
    static let appConfigDidSave = Notification.Name("InkletAppConfigDidSave")
}

private extension PromptMode {
    static let builtInIDs: Set<String> = [
        PromptMode.translateToEnglishID,
        PromptMode.improveWritingID,
        PromptMode.makeConciseID,
        PromptMode.professionalToneID,
        PromptMode.friendlyReplyID,
        PromptMode.customPromptID
    ]
}

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General"
    case providers = "Providers"
    case promptModes = "Prompt Modes"
    case permissions = "Permissions"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: L10n.text("settings.section.general")
        case .providers: L10n.text("settings.section.providers")
        case .promptModes: L10n.text("settings.section.promptModes")
        case .permissions: L10n.text("settings.section.permissions")
        }
    }

    var icon: String {
        switch self {
        case .general: "gearshape"
        case .providers: "sparkles"
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
        .frame(width: 860, height: 540)
        .background(InkletTheme.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: InkletTheme.cornerRadius))
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
                Text("Inklet")
                    .font(.system(size: 14, weight: .semibold))
                Text(L10n.text("settings.sidebar.preferences"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) { Divider().opacity(0.45) }

            VStack(spacing: 0) {
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
                        .foregroundStyle(selectedSection == section ? .primary : .secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            selectedSection == section ? InkletTheme.primary.opacity(0.18) : Color.clear
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 6)

            Spacer()
            Text(L10n.format("settings.version", "1.0.0"))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .top) { Divider().opacity(0.45) }
        }
        .frame(width: 172)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
        .overlay(alignment: .trailing) { Divider().opacity(0.55) }
    }

    private var detail: some View {
        VStack(spacing: 0) {
            detailHeader
            Divider().opacity(0.55)

            Group {
                switch selectedSection {
                case .general:
                    ScrollView {
                        generalPanel
                            .padding(20)
                    }
                case .providers:
                    providersPanel
                case .promptModes:
                    promptModesPanel
                case .permissions:
                    ScrollView {
                        permissionsPanel
                            .padding(20)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider().opacity(0.5)
            footer
        }
    }

    private var detailHeader: some View {
        HStack {
            Text(selectedSection.title)
                .font(.system(size: 18, weight: .semibold))
            Spacer()
            Button {
                NSApp.keyWindow?.close()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(.quaternary.opacity(0.01), in: RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private var sectionDescription: String {
        switch selectedSection {
        case .general:
            L10n.text("settings.description.general")
        case .providers:
            L10n.text("settings.description.providers")
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
                    Slider(value: $model.config.temperature, in: 0...2, step: 0.1)
                    Text(model.config.temperature, format: .number.precision(.fractionLength(1)))
                        .font(.body.monospacedDigit())
                        .frame(width: 42, alignment: .trailing)
                }
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
                .padding(20)
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
                .padding(.top, 8)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.16))
                Divider().opacity(0.55)
                Button {
                    model.addPromptMode()
                } label: {
                    Label(L10n.text("settings.mode.add"), systemImage: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35), in: RoundedRectangle(cornerRadius: 7))
                        .overlay {
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                                .foregroundStyle(InkletTheme.subtleBorder)
                        }
                }
                .buttonStyle(.plain)
                .padding(10)
            }
            .frame(width: 288)
            .overlay(alignment: .trailing) { Divider().opacity(0.55) }

            if let index = model.selectedPromptModeIndex {
                ScrollView {
                    promptModeDetail(index: index)
                        .frame(maxWidth: 560, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
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
                        .textFieldStyle(.roundedBorder)
                }

                settingsRow(L10n.text("settings.row.description"), help: L10n.text("settings.help.description")) {
                    TextField(L10n.text("settings.row.description"), text: $model.config.promptModes[index].description)
                        .textFieldStyle(.roundedBorder)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.text("settings.row.systemPrompt"))
                    .font(.system(size: 13, weight: .semibold))

                TextEditor(text: $model.config.promptModes[index].systemPrompt)
                    .font(.system(size: 13))
                    .scrollContentBackground(.hidden)
                    .background(InkletTextEditorChromeNormalizer())
                    .frame(height: 178)
                    .padding(10)
                    .modifier(InkletFieldModifier())
            }

            settingsToggle(
                title: L10n.text("settings.mode.visibleInMenu"),
                subtitle: L10n.text("settings.mode.visibleInMenuHelp"),
                isOn: $model.config.promptModes[index].isVisible
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
                        Text(L10n.text("settings.permission.description"))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
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
            .background(InkletTheme.elevatedBackground, in: RoundedRectangle(cornerRadius: 9))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .stroke(InkletTheme.subtleBorder)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.text("settings.privacy.title"))
                    .font(.system(size: 14, weight: .semibold))
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.text("settings.privacy.keychain"))
                    Text(L10n.text("settings.privacy.provider"))
                    Text(L10n.text("settings.privacy.clipboard"))
                }
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(InkletTheme.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .stroke(InkletTheme.subtleBorder)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if !model.message.isEmpty {
                Label(model.message, systemImage: isSavedMessage ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(isSavedMessage ? .green : .red)
                    .lineLimit(2)
            } else {
                Text(L10n.text("settings.footer.pending"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                model.save()
            } label: {
                Label(L10n.text("settings.save"), systemImage: "checkmark")
            }
            .keyboardShortcut("s", modifiers: .command)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }

    private func settingsPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(0)
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
                    .foregroundStyle(.primary)
                Spacer()
            }
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
            if !help.isEmpty {
                Text(help)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func settingsToggle(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
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
        tableView.rowHeight = 36
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .none
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.delegate = context.coordinator
        tableView.dataSource = context.coordinator
        tableView.registerForDraggedTypes([Coordinator.dragPasteboardType])

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.horizontalScrollElasticity = .none
        scrollView.autohidesScrollers = true
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

        if tableView.tableColumns.first?.width != scrollView.bounds.width {
            tableView.tableColumns.first?.width = scrollView.bounds.width
        }

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

private final class PromptModeTableCellView: NSTableCellView {
    private let selectionBackground = NSView()
    private let dragHandle = NSImageView()
    private let titleField = NSTextField(labelWithString: "")
    private let visibilityButton = NSButton()
    private let deleteButton = NSButton()

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
        titleField.stringValue = mode.name.isEmpty ? L10n.text("settings.mode.untitled") : mode.localizedName
        titleField.font = .systemFont(ofSize: 13, weight: isSelected ? .semibold : .regular)
        titleField.textColor = isSelected ? .labelColor : .secondaryLabelColor
        selectionBackground.layer?.backgroundColor = isSelected
            ? NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor
            : NSColor.clear.cgColor
        dragHandle.contentTintColor = isSelected ? .secondaryLabelColor : .tertiaryLabelColor
        visibilityButton.image = NSImage(systemSymbolName: mode.isVisible ? "eye" : "eye.slash", accessibilityDescription: nil)?
            .withSymbolConfiguration(symbolConfiguration)
        visibilityButton.contentTintColor = mode.isVisible ? .secondaryLabelColor : .tertiaryLabelColor
        visibilityButton.toolTip = mode.isVisible ? L10n.text("settings.mode.visible") : L10n.text("settings.mode.hidden")
        visibilityButton.identifier = NSUserInterfaceItemIdentifier(mode.id)
        visibilityButton.target = target
        visibilityButton.action = #selector(PromptModeTableView.Coordinator.toggleVisibility(_:))

        deleteButton.identifier = NSUserInterfaceItemIdentifier(mode.id)
        deleteButton.target = target
        deleteButton.action = #selector(PromptModeTableView.Coordinator.deleteMode(_:))
        deleteButton.isEnabled = canDelete
        deleteButton.contentTintColor = canDelete ? .secondaryLabelColor : .tertiaryLabelColor
        deleteButton.toolTip = L10n.text("settings.mode.delete")
    }

    private func buildView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        selectionBackground.wantsLayer = true
        selectionBackground.layer?.cornerRadius = 7
        selectionBackground.layer?.cornerCurve = .continuous
        selectionBackground.layer?.backgroundColor = NSColor.clear.cgColor
        selectionBackground.translatesAutoresizingMaskIntoConstraints = false
        addSubview(selectionBackground)

        let symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        dragHandle.image = NSImage(systemSymbolName: "line.3.horizontal", accessibilityDescription: nil)?
            .withSymbolConfiguration(symbolConfiguration)
        dragHandle.contentTintColor = .tertiaryLabelColor
        dragHandle.setContentHuggingPriority(.required, for: .horizontal)
        dragHandle.setContentCompressionResistancePriority(.required, for: .horizontal)
        dragHandle.toolTip = L10n.text("settings.mode.dragToSort")
        dragHandle.translatesAutoresizingMaskIntoConstraints = false

        titleField.lineBreakMode = .byTruncatingTail
        titleField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        titleField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleField.translatesAutoresizingMaskIntoConstraints = false

        configureIconButton(visibilityButton)
        configureIconButton(deleteButton)
        deleteButton.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)?
            .withSymbolConfiguration(symbolConfiguration)
        deleteButton.contentTintColor = .secondaryLabelColor

        addSubview(dragHandle)
        addSubview(titleField)
        addSubview(visibilityButton)
        addSubview(deleteButton)

        NSLayoutConstraint.activate([
            dragHandle.widthAnchor.constraint(equalToConstant: 18),
            visibilityButton.widthAnchor.constraint(equalToConstant: 24),
            visibilityButton.heightAnchor.constraint(equalToConstant: 24),
            deleteButton.widthAnchor.constraint(equalToConstant: 24),
            deleteButton.heightAnchor.constraint(equalToConstant: 24),
            selectionBackground.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            selectionBackground.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            selectionBackground.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            selectionBackground.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
            dragHandle.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            dragHandle.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleField.leadingAnchor.constraint(equalTo: dragHandle.trailingAnchor, constant: 12),
            titleField.trailingAnchor.constraint(equalTo: visibilityButton.leadingAnchor, constant: -12),
            titleField.centerYAnchor.constraint(equalTo: centerYAnchor),
            visibilityButton.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -10),
            visibilityButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            deleteButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            deleteButton.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
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
            window?.makeFirstResponder(self)
            updateDisplay()
        }

        override func resignFirstResponder() -> Bool {
            isRecording = false
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
    }
}
