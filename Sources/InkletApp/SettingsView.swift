import AppKit
import SwiftUI
import InkletCore

private extension SelectionForceSelectionMode {
    var localizedDisplayName: String {
        switch self {
        case .disabled: L10n.text("settings.forceSelection.disabled")
        case .menuCopyOnly: L10n.text("settings.forceSelection.menuCopyOnly")
        case .menuCopyThenShortcut: L10n.text("settings.forceSelection.menuCopyThenShortcut")
        case .shortcutThenMenuCopy: L10n.text("settings.forceSelection.shortcutThenMenuCopy")
        }
    }
}

/// Sidebar order follows docs/DESIGN.md; About sits apart at the bottom of the sidebar.
enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General"
    case aiModels = "AI Models"
    case writeAssistant = "Write Assistant"
    case promptModes = "Prompt Modes"
    case dictation = "Live Dictation"
    case selectionAssistant = "Selection Assistant"
    case history = "History"
    case about = "About"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: L10n.text("settings.section.general")
        case .aiModels: L10n.text("settings.section.aiModels")
        case .writeAssistant: L10n.text("settings.section.writeAssistant")
        case .dictation: L10n.text("settings.section.dictation")
        case .selectionAssistant: L10n.text("settings.section.selectionAssistant")
        case .history: L10n.text("settings.section.history")
        case .promptModes: L10n.text("settings.section.promptModes")
        case .about: L10n.text("settings.section.about")
        }
    }

    var icon: String {
        switch self {
        case .general: "gearshape"
        case .aiModels: "cpu"
        case .writeAssistant: "pencil.and.scribble"
        case .dictation: "mic"
        case .selectionAssistant: "text.viewfinder"
        case .history: "clock.arrow.circlepath"
        case .promptModes: "slider.horizontal.3"
        case .about: "info.circle"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model: SettingsViewModel
    @ObservedObject var migrationPresentationModel: LegacyMigrationPresentationModel
    @State private var selectedSection: SettingsSection
    @State private var promptModePendingDeletionID: String?
    @State private var isConfirmingClearHistory = false
    @State private var copiedHistoryControlID: String?
    @State private var historyCopyFeedbackTask: Task<Void, Never>?
    @State private var localeIdentifier = L10n.resolvedLanguage.localeIdentifier
    private let onAppearanceChange: (AppAppearance) -> Void
    private let onRequestMigrationImport: () -> Void
    private let onRetryMigrationRelaunch: () -> Void
    private let onQuitForMigration: () -> Void

    init(
        model: SettingsViewModel,
        migrationPresentationModel: LegacyMigrationPresentationModel,
        initialSection: SettingsSection = .general,
        onAppearanceChange: @escaping (AppAppearance) -> Void = { _ in },
        onRequestMigrationImport: @escaping () -> Void = {},
        onRetryMigrationRelaunch: @escaping () -> Void = {},
        onQuitForMigration: @escaping () -> Void = {}
    ) {
        self.model = model
        self.migrationPresentationModel = migrationPresentationModel
        _selectedSection = State(initialValue: initialSection)
        self.onAppearanceChange = onAppearanceChange
        self.onRequestMigrationImport = onRequestMigrationImport
        self.onRetryMigrationRelaunch = onRetryMigrationRelaunch
        self.onQuitForMigration = onQuitForMigration
    }

    private var isSuccessMessage: Bool {
        model.message == L10n.text("settings.saved") || model.message == L10n.text("settings.history.cleared")
    }

    private var pronunciationSpeedBinding: Binding<Double> {
        Binding(
            get: { model.config.selectionActions.pronunciationSpeed },
            set: {
                model.config.selectionActions.pronunciationSpeed = SelectionActionsConfig.clampedPronunciationSpeed($0)
            }
        )
    }

    private var pronunciationSpeedText: String {
        L10n.format("settings.aiPronunciation.speedValue", model.config.selectionActions.pronunciationSpeed)
    }

    private var usesOpenAIPronunciation: Bool {
        model.config.selectionActions.pronunciationEngine == .openAI
    }

    private var isPronunciationPreviewPlaying: Bool {
        if case .playing(let voice)? = model.pronunciationPreviewState {
            return voice == model.config.selectionActions.pronunciationVoice
        }
        return false
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            detail
                .background(InkletTheme.surface)
        }
        .frame(width: 860, height: 560)
        .environment(\.locale, Locale(identifier: localeIdentifier))
        .ignoresSafeArea()
        .task {
            await model.refreshModelCatalogIfNeeded()
        }
        .onAppear {
            model.refreshPermissions()
            model.refreshMicrophoneOptions()
        }
        .onChange(of: model.config.appearance) {
            onAppearanceChange(model.config.appearance)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refreshPermissions()
        }
        .onReceive(NotificationCenter.default.publisher(for: .inkletLanguageDidChange).receive(on: RunLoop.main)) { _ in
            localeIdentifier = L10n.resolvedLanguage.localeIdentifier
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
        .alert(
            L10n.text("settings.history.clearConfirmTitle"),
            isPresented: $isConfirmingClearHistory
        ) {
            Button(L10n.text("settings.history.clear"), role: .destructive) {
                model.clearHistory()
            }
            Button(L10n.text("settings.cancel"), role: .cancel) {}
        } message: {
            Text(L10n.text("settings.history.clearConfirmMessage"))
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Room for the system traffic lights in the transparent titlebar.
            Color.clear
                .frame(height: SettingsLayoutMetrics.titlebarInset)

            VStack(spacing: 2) {
                ForEach(SettingsSection.allCases.filter { $0 != .about }) { section in
                    sidebarButton(section)
                }
            }

            Spacer(minLength: InkletTheme.Spacing.md)

            sidebarButton(.about)
        }
        .padding(.horizontal, InkletTheme.Spacing.xs)
        .padding(.bottom, InkletTheme.Spacing.sm)
        .frame(width: SettingsLayoutMetrics.sidebarWidth)
        .frame(maxHeight: .infinity)
        .disabled(model.isMigrationMaintenanceActive)
        .background(InkletMaterialBackground(material: .sidebar))
        .overlay(alignment: .trailing) {
            InkletTheme.hairline.frame(width: 1)
        }
    }

    private func sidebarButton(_ section: SettingsSection) -> some View {
        Button {
            selectedSection = section
        } label: {
            SettingsSidebarLabel(
                section: section,
                isSelected: selectedSection == section
            )
        }
        .buttonStyle(.plain)
        .help(section.title)
    }

    private var detail: some View {
        VStack(spacing: 0) {
            detailHeader

            Group {
                switch selectedSection {
                case .general:
                    settingsPage {
                        generalPanel
                    }
                case .aiModels:
                    settingsPage {
                        aiModelsPanel
                    }
                    .disabled(model.isMigrationMaintenanceActive)
                case .writeAssistant:
                    writeAssistantPanel
                        .disabled(model.isMigrationMaintenanceActive)
                case .promptModes:
                    promptModesPanel
                        .disabled(model.isMigrationMaintenanceActive)
                case .dictation:
                    settingsPage {
                        dictationSettingsPanel
                    }
                    .disabled(model.isMigrationMaintenanceActive)
                case .selectionAssistant:
                    settingsPage {
                        selectionActionsPanel
                    }
                    .disabled(model.isMigrationMaintenanceActive)
                case .history:
                    historyPanel
                        .disabled(model.isMigrationMaintenanceActive)
                case .about:
                    settingsPage {
                        aboutPanel
                    }
                    .disabled(model.isMigrationMaintenanceActive)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    /// The window closes with its traffic lights or Esc, so the header holds only the title
    /// and the last save status.
    private var detailHeader: some View {
        HStack(spacing: InkletTheme.Spacing.sm) {
            Text(selectedSection.title)
                .font(InkletTheme.Typography.pageTitle)
                .tracking(-0.2)
                .foregroundStyle(InkletTheme.label)
                .lineLimit(1)
            Spacer(minLength: InkletTheme.Spacing.md)
            saveStatus
        }
        .padding(.horizontal, InkletTheme.Spacing.xl)
        .frame(height: SettingsLayoutMetrics.headerHeight)
    }

    /// Settings save on their own; the header only reports the last save or a problem.
    @ViewBuilder
    private var saveStatus: some View {
        if !model.message.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: InkletTheme.Spacing.xxs) {
                Image(systemName: isSuccessMessage ? "checkmark.circle" : "exclamationmark.circle")
                    .foregroundStyle(isSuccessMessage ? InkletTheme.statusSuccess : InkletTheme.statusError)
                Text(model.message)
                    .foregroundStyle(isSuccessMessage ? InkletTheme.secondaryLabel : InkletTheme.label)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(InkletTheme.Typography.caption)
            .frame(maxWidth: 320, alignment: .trailing)
            .help(L10n.text("settings.footer.pending"))
        }
    }

    private var generalPanel: some View {
        VStack(alignment: .leading, spacing: InkletTheme.Spacing.xl) {
            if migrationPresentationModel.phase != .hidden {
                migrationNoticeCard
            }

            VStack(alignment: .leading, spacing: InkletTheme.Spacing.xl) {
                settingsGroup(L10n.text("settings.group.interface")) {
                    settingsRow(L10n.text("settings.row.language"), help: L10n.text("settings.help.language")) {
                        Picker("", selection: $model.interfaceLanguage) {
                            ForEach(InterfaceLanguage.allCases) { language in
                                Text(language.localizedDisplayName).tag(language)
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }

                    settingsRow(L10n.text("settings.row.writingLanguage"), help: L10n.text("settings.help.writingLanguage")) {
                        Picker("", selection: $model.writingLanguage) {
                            ForEach(SelectionTranslationLanguage.writingLanguageCases) { language in
                                Text(language.localizedDisplayName).tag(language)
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }

                    settingsRow(L10n.text("settings.row.appearance"), help: L10n.text("settings.help.appearance")) {
                        Picker("", selection: $model.config.appearance) {
                            ForEach(AppAppearance.allCases) { appearance in
                                Text(appearance.localizedDisplayName).tag(appearance)
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                }

                systemPermissionsPanel
            }
            .disabled(model.isMigrationMaintenanceActive)
        }
    }

    /// One card per capability, each starting with its engine, and the API keys they share at the end.
    /// The feature pages keep only their own settings and name the engine they use.
    private var aiModelsPanel: some View {
        VStack(alignment: .leading, spacing: InkletTheme.Spacing.xl) {
            settingsGroup(L10n.text("settings.group.textEngine")) {
                textEngineRows
            }

            settingsGroup(L10n.text("settings.group.speechToText")) {
                speechToTextRows
            }

            settingsGroup(L10n.text("settings.group.textToSpeech")) {
                settingsRow(
                    L10n.text("settings.row.engine"),
                    help: L10n.text("settings.help.speechOutputEngine"),
                    warning: openAIKeyWarning(isNeeded: usesOpenAIPronunciation)
                ) {
                    Picker("", selection: $model.config.selectionActions.pronunciationEngine) {
                        ForEach(SelectionPronunciationEngine.allCases) { engine in
                            Text(engine.localizedName).tag(engine)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }

            settingsGroup(L10n.text("settings.group.apiKeys")) {
                apiKeyRows
            }

            if !model.usesBuiltInDictation {
                openAIDictationAdvancedSettings
            }
        }
    }

    @ViewBuilder
    private var textEngineRows: some View {
        let selectedProviderBinding = Binding(
            get: { model.config.providerID },
            set: { model.selectProvider($0) }
        )

        settingsRow(
            L10n.text("settings.row.engine"),
            help: L10n.text("settings.help.textEngine"),
            warning: textEngineKeyWarning
        ) {
            Picker("", selection: selectedProviderBinding) {
                ForEach(model.cloudProviders) { preset in
                    Text(model.providerDisplayName(preset)).tag(preset.id)
                }
                Divider()
                ForEach(model.localProviders) { preset in
                    Text(model.providerDisplayName(preset)).tag(preset.id)
                }
            }
            .labelsHidden()
            .fixedSize()
        }

        if model.isBuiltInProvider {
            builtInModelRow
        } else {
            if model.isLocalServerProvider {
                localServerRow
            }

            if model.isCustomOpenAICompatibleProvider {
                settingsRow(L10n.text("settings.row.endpoint"), help: L10n.text("settings.help.endpoint")) {
                    TextField(
                        LLMProviderPreset.customOpenAICompatible.endpoint.absoluteString,
                        text: $model.config.customOpenAICompatibleEndpoint
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: SettingsLayoutMetrics.fieldWidth)
                }
            }

            textModelRow
        }
    }

    @ViewBuilder
    private var speechToTextRows: some View {
        settingsRow(
            L10n.text("settings.row.engine"),
            help: L10n.text("settings.help.dictationEngine"),
            warning: openAIKeyWarning(isNeeded: !model.usesBuiltInDictation)
        ) {
            if model.isBuiltInEngineAvailable {
                Picker("", selection: $model.config.voiceInput.engine) {
                    ForEach(VoiceInputConfig.Engine.allCases) { engine in
                        Text(engine.localizedName).tag(engine)
                    }
                }
                .labelsHidden()
                .fixedSize()
            } else {
                Text(VoiceInputConfig.Engine.openAI.localizedName)
                    .font(InkletTheme.Typography.body)
                    .foregroundStyle(InkletTheme.secondaryLabel)
                    .fixedSize()
            }
        }

        if model.usesBuiltInDictation {
            dictationModelRow
        }
    }

    /// Every key is typed once. OpenAI is always listed because text to speech needs it; the selected
    /// text provider's key joins it when that provider is another cloud service.
    @ViewBuilder
    private var apiKeyRows: some View {
        settingsRow(L10n.text("settings.row.openAIAPIKey"), help: L10n.text("settings.help.openAIAPIKey.shared")) {
            // While OpenAI handles text, its key is the provider key; both bindings edit the same stored key.
            SecureField(
                LLMProviderPreset.openAI.apiKeyPlaceholder,
                text: model.usesOpenAIForWriting ? $model.providerAPIKey : $model.openAIAPIKey
            )
            .textFieldStyle(.roundedBorder)
            .frame(width: SettingsLayoutMetrics.fieldWidth)
        }

        if model.showsAPIKeyField, !model.usesOpenAIForWriting {
            settingsRow(
                L10n.format("settings.row.providerAPIKey", model.selectedProvider.localizedName),
                help: L10n.text("settings.help.apiKey")
            ) {
                SecureField(model.selectedProvider.apiKeyPlaceholder, text: $model.providerAPIKey)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: SettingsLayoutMetrics.fieldWidth)
            }
        }
    }

    private func openAIKeyWarning(isNeeded: Bool) -> String? {
        isNeeded && model.isOpenAIAPIKeyMissing ? L10n.text("settings.apiKey.openAIMissing") : nil
    }

    /// The selected text provider's own key, or the OpenAI key while OpenAI handles text.
    private var textEngineKeyWarning: String? {
        if model.usesOpenAIForWriting {
            return openAIKeyWarning(isNeeded: true)
        }
        guard model.selectedProvider.requiresAPIKey,
              model.providerAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }
        return L10n.format("settings.apiKey.providerMissing", model.selectedProvider.localizedName)
    }

    /// The first row on a feature page: which engine it uses, with a way to the AI Models page.
    private func engineNoteRow(_ engine: String, warning: String? = nil) -> some View {
        VStack(spacing: 0) {
            InkletRowDivider()
            HStack(spacing: InkletTheme.Spacing.md) {
                Text(L10n.format("settings.engineNote", engine))
                    .font(InkletTheme.Typography.help)
                    .foregroundStyle(InkletTheme.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let warning {
                    Label(warning, systemImage: "exclamationmark.triangle")
                        .font(InkletTheme.Typography.caption)
                        .foregroundStyle(InkletTheme.statusWarning)
                        .fixedSize()
                }
                Button(L10n.text("settings.engineNote.change")) {
                    selectedSection = .aiModels
                }
                .buttonStyle(InkletButtonStyle(kind: .ghost, size: .small))
                .fixedSize()
            }
            .padding(.horizontal, InkletTheme.Spacing.sm)
            .padding(.vertical, InkletTheme.Spacing.xs)
            .frame(minHeight: SettingsLayoutMetrics.rowHeight)
        }
    }

    private var textEngineNote: String {
        if model.isBuiltInProvider {
            return "\(model.selectedProvider.localizedName) · \(model.selectedBuiltInModel.displayName)"
        }
        return "\(model.selectedProvider.localizedName) · \(model.selectedProvider.displayModelName(model.config.model))"
    }

    private var dictationEngineNote: String {
        model.usesBuiltInDictation
            ? "\(VoiceInputConfig.Engine.builtIn.localizedName) · \(model.dictationModel.displayName)"
            : VoiceInputConfig.Engine.openAI.localizedName
    }

    @ViewBuilder
    private var builtInModelRow: some View {
        let builtInModel = model.selectedBuiltInModel
        let selectedBuiltInModelBinding = Binding(
            get: { model.selectedBuiltInModel.id },
            set: { model.selectBuiltInModel($0) }
        )
        let detail = L10n.format(
            "settings.localModel.detail",
            builtInModel.localizedDownloadSize,
            builtInModel.recommendedMemoryGB
        )

        settingsRow(L10n.text("settings.row.model"), help: L10n.text("settings.help.localModel")) {
            Picker("", selection: selectedBuiltInModelBinding) {
                ForEach(BuiltInModel.all) { option in
                    Text(model.builtInModelTitle(option)).tag(option.id)
                }
            }
            .labelsHidden()
            .fixedSize()
        }

        if model.isBuiltInEngineAvailable {
            modelStatusRow(detail: detail) {
                builtInModelDownloadControls(for: builtInModel)
            }
        } else {
            modelStatusRow(detail: detail, warning: L10n.text("error.localModel.engineMissing")) {
                EmptyView()
            }
        }
    }

    /// A model's download size on the left and its download, progress or delete controls on the right.
    private func modelStatusRow<Controls: View>(
        detail: String,
        warning: String? = nil,
        @ViewBuilder controls: () -> Controls
    ) -> some View {
        VStack(spacing: 0) {
            InkletRowDivider()
            HStack(spacing: InkletTheme.Spacing.md) {
                VStack(alignment: .leading, spacing: InkletTheme.Spacing.xxs) {
                    Text(detail)
                        .font(InkletTheme.Typography.help)
                        .foregroundStyle(InkletTheme.secondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                    if let warning {
                        Label(warning, systemImage: "exclamationmark.triangle")
                            .font(InkletTheme.Typography.help)
                            .foregroundStyle(InkletTheme.statusWarning)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                controls()
            }
            .padding(.horizontal, InkletTheme.Spacing.sm)
            .padding(.vertical, InkletTheme.Spacing.xs)
            .frame(minHeight: SettingsLayoutMetrics.rowHeight)
        }
    }

    private func builtInModelDownloadControls(for builtInModel: BuiltInModel) -> some View {
        modelDownloadControls(
            state: model.builtInModelState(builtInModel),
            download: { model.downloadBuiltInModel(builtInModel) },
            cancel: { model.cancelBuiltInModelDownload(builtInModel) },
            delete: { model.deleteBuiltInModel(builtInModel) }
        )
    }

    @ViewBuilder
    private func modelDownloadControls(
        state: BuiltInModelDownloadState,
        download: @escaping @MainActor () -> Void,
        cancel: @escaping @MainActor () -> Void,
        delete: @escaping @MainActor () -> Void
    ) -> some View {
        switch state {
        case .notDownloaded:
            Button(L10n.text("settings.localModel.download"), action: download)
                .buttonStyle(InkletButtonStyle(kind: .primary, size: .small))
                .fixedSize()
        case .downloading(let fraction):
            HStack(spacing: InkletTheme.Spacing.xs) {
                ProgressView(value: fraction)
                    .frame(width: 120)
                Text(L10n.format("settings.localModel.downloading", fraction * 100))
                    .font(InkletTheme.Typography.caption.monospacedDigit())
                    .foregroundStyle(InkletTheme.secondaryLabel)
                    .fixedSize()
                Button(L10n.text("settings.localModel.cancel"), action: cancel)
                    .buttonStyle(InkletButtonStyle(kind: .secondary, size: .small))
                    .fixedSize()
            }
        case .verifying:
            HStack(spacing: InkletTheme.Spacing.xs) {
                ProgressView()
                    .controlSize(.small)
                Text(L10n.text("settings.localModel.verifying"))
                    .font(InkletTheme.Typography.help)
                    .foregroundStyle(InkletTheme.secondaryLabel)
                    .fixedSize()
            }
        case .ready:
            HStack(spacing: InkletTheme.Spacing.sm) {
                Label(L10n.text("settings.localModel.ready"), systemImage: "checkmark.circle.fill")
                    .font(InkletTheme.Typography.caption)
                    .foregroundStyle(InkletTheme.statusSuccess)
                    .fixedSize()
                Button(L10n.text("settings.localModel.delete"), action: delete)
                    .buttonStyle(InkletButtonStyle(kind: .secondary, size: .small))
                    .fixedSize()
            }
        case .failed(let message):
            VStack(alignment: .trailing, spacing: InkletTheme.Spacing.xs) {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(InkletTheme.Typography.help)
                    .foregroundStyle(InkletTheme.statusWarning)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
                Button(L10n.text("settings.localModel.retry"), action: download)
                    .buttonStyle(InkletButtonStyle(kind: .primary, size: .small))
                    .fixedSize()
            }
            .frame(maxWidth: SettingsLayoutMetrics.fieldWidth, alignment: .trailing)
        }
    }

    private var localServerRow: some View {
        settingsRow(
            L10n.text("settings.row.localServer"),
            help: L10n.format("settings.help.localServer", model.selectedProvider.endpoint.absoluteString)
        ) {
            HStack(spacing: InkletTheme.Spacing.xs) {
                switch model.localServerStatus {
                case .checking:
                    ProgressView()
                        .controlSize(.small)
                    Text(L10n.text("settings.localServer.checking"))
                        .foregroundStyle(InkletTheme.secondaryLabel)
                        .fixedSize()
                case .connected(let modelCount):
                    Label(
                        L10n.format("settings.localServer.connected", modelCount),
                        systemImage: "checkmark.circle.fill"
                    )
                    .foregroundStyle(InkletTheme.statusSuccess)
                    .fixedSize()
                case .unreachable:
                    Label(
                        L10n.format("settings.localServer.unreachable", model.selectedProvider.name),
                        systemImage: "exclamationmark.triangle"
                    )
                    .foregroundStyle(InkletTheme.statusWarning)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 200, alignment: .trailing)
                case nil:
                    EmptyView()
                }
                Button(L10n.text("settings.localServer.refresh")) {
                    model.refreshLocalServerModels()
                }
                .buttonStyle(InkletButtonStyle(kind: .secondary, size: .small))
                .fixedSize()
                .disabled(model.localServerStatus == .checking)
            }
            .font(InkletTheme.Typography.caption)
        }
        .onAppear {
            if model.localServerStatus == nil {
                model.refreshLocalServerModels()
            }
        }
    }

    private var migrationNoticeCard: some View {
        VStack(alignment: .leading, spacing: InkletTheme.Spacing.sm) {
            HStack(alignment: .top, spacing: InkletTheme.Spacing.sm) {
                Image(systemName: "externaldrive.badge.exclamationmark")
                    .font(.system(size: InkletTheme.IconSize.large, weight: .medium))
                    .foregroundStyle(InkletTheme.statusWarning)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: InkletTheme.Spacing.xxs) {
                    Text(L10n.text("legacyMigration.notice.title"))
                        .font(InkletTheme.Typography.body.weight(.semibold))
                        .foregroundStyle(InkletTheme.label)
                    Text(migrationNoticeMessage)
                        .font(InkletTheme.Typography.help)
                        .foregroundStyle(InkletTheme.secondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: InkletTheme.Spacing.xs) {
                if migrationPresentationModel.phase == .relaunchFailed {
                    Button(L10n.text("legacyMigration.action.quit"), action: onQuitForMigration)
                        .buttonStyle(InkletButtonStyle(kind: .secondary))
                        .fixedSize()
                }
                migrationPrimaryAction
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(InkletTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .inkletCard()
    }

    private var migrationNoticeMessage: String {
        switch migrationPresentationModel.phase {
        case .failed:
            switch migrationPresentationModel.failureReason {
            case .invalidSelection:
                L10n.text("legacyMigration.import.invalidSelection")
            case .partialFailure:
                L10n.text("legacyMigration.import.partialFailure")
            case .importFailed, .none:
                L10n.text("legacyMigration.import.failed")
            }
        case .relaunching:
            L10n.text("legacyMigration.import.relaunching")
        case .relaunchFailed:
            L10n.text("legacyMigration.import.relaunchFailed")
        case .hidden, .needsImport, .selecting, .importing:
            L10n.text("legacyMigration.notice.message")
        }
    }

    @ViewBuilder
    private var migrationPrimaryAction: some View {
        switch migrationPresentationModel.phase {
        case .importing, .relaunching:
            migrationActionButton(
                titleKey: migrationPresentationModel.phase == .importing
                    ? "legacyMigration.import.progress"
                    : "legacyMigration.import.relaunchProgress",
                systemImage: "square.and.arrow.down",
                showsProgress: true,
                isEnabled: false,
                action: {}
            )
        case .relaunchFailed:
            migrationActionButton(
                titleKey: "legacyMigration.action.retryRelaunch",
                systemImage: "arrow.clockwise",
                showsProgress: false,
                isEnabled: true,
                action: onRetryMigrationRelaunch
            )
        case .hidden, .needsImport, .selecting, .failed:
            migrationActionButton(
                titleKey: "legacyMigration.action.importOldData",
                systemImage: "square.and.arrow.down",
                showsProgress: false,
                isEnabled: migrationPresentationModel.canStartImport,
                action: onRequestMigrationImport
            )
        }
    }

    private func migrationActionButton(
        titleKey: String,
        systemImage: String,
        showsProgress: Bool,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label {
                Text(L10n.text(titleKey))
            } icon: {
                Group {
                    if showsProgress {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: systemImage)
                    }
                }
                .frame(width: 14, height: 14)
            }
            .font(.system(size: 12, weight: .semibold))
            .frame(width: SettingsLayoutMetrics.migrationActionWidth, height: 28)
        }
        .buttonStyle(InkletButtonStyle(kind: .primary))
        .fixedSize()
        .disabled(!isEnabled)
        .help(L10n.text("legacyMigration.settings.help"))
        .accessibilityLabel(L10n.text(titleKey))
    }

    /// The model for a cloud or local server provider; the built-in provider uses `builtInModelRow`.
    private var textModelRow: some View {
        let selectedModelBinding = Binding(
            get: { model.selectedModelMenuValue },
            set: { model.selectModelMenuValue($0) }
        )

        return settingsRow(L10n.text("settings.row.model"), help: L10n.format("settings.help.model.default", model.selectedProvider.defaultModel)) {
            VStack(alignment: .trailing, spacing: InkletTheme.Spacing.xs) {
                if !model.selectedProviderModelOptions.isEmpty {
                    Picker("", selection: selectedModelBinding) {
                        ForEach(model.selectedProviderModelOptions, id: \.self) { modelID in
                            Text(model.modelMenuTitle(for: modelID)).tag(modelID)
                        }
                        Divider()
                        Text(L10n.text("settings.model.custom")).tag(SettingsViewModel.customModelMenuID)
                    }
                    .labelsHidden()
                    .fixedSize()
                }

                if model.shouldShowCustomModelField {
                    TextField(model.selectedProvider.defaultModel, text: $model.config.model)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: SettingsLayoutMetrics.fieldWidth)
                    if !model.selectedModelIsDefault {
                        Text(L10n.text("settings.model.customized"))
                            .font(InkletTheme.Typography.caption)
                            .foregroundStyle(InkletTheme.secondaryLabel)
                    }
                }

                if model.isRefreshingModelCatalog {
                    Text(L10n.text("settings.model.refreshing"))
                        .font(InkletTheme.Typography.caption)
                        .foregroundStyle(InkletTheme.tertiaryLabel)
                }
            }
        }
    }

    private var writeAssistantControls: some View {
        settingsGroup {
            engineNoteRow(textEngineNote, warning: textEngineKeyWarning)

            settingsRow(L10n.text("settings.row.hotkey"), help: L10n.text("settings.help.hotkey")) {
                HotkeyRecorderField(hotkey: $model.config.hotkey)
                    .frame(width: 200, height: InkletTheme.ControlHeight.regular)
            }

            settingsRow(L10n.text("settings.row.timeout"), help: L10n.text("settings.help.timeout")) {
                HStack(spacing: InkletTheme.Spacing.xs) {
                    Text(L10n.format("settings.seconds", Int(model.config.timeoutSeconds)))
                        .font(InkletTheme.Typography.body.monospacedDigit())
                        .foregroundStyle(InkletTheme.label)
                    Stepper("", value: $model.config.timeoutSeconds, in: 1...120, step: 1)
                        .labelsHidden()
                }
                .fixedSize()
            }
        }
    }

    private var writeAssistantPanel: some View {
        settingsPage {
            writeAssistantControls
        }
    }

    private var dictationSettingsPanel: some View {
        let selectedMicrophoneBinding = Binding(
            get: { model.selectedMicrophoneMenuID },
            set: { model.selectedMicrophoneMenuID = $0 }
        )

        return VStack(alignment: .leading, spacing: InkletTheme.Spacing.xl) {
            settingsGroup {
                settingsRow(
                    L10n.text("settings.row.dictationEnabled"),
                    help: L10n.text("settings.help.dictationEnabled")
                ) {
                    Toggle("", isOn: $model.config.voiceInput.isEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                engineNoteRow(dictationEngineNote, warning: openAIKeyWarning(isNeeded: !model.usesBuiltInDictation))
            }

            settingsGroup {
                settingsRow(
                    L10n.text("settings.row.dictationShortcut"),
                    help: L10n.text("settings.help.dictationShortcut")
                ) {
                    Picker("", selection: $model.config.voiceInput.shortcut) {
                        ForEach(VoiceInputConfig.Shortcut.settingsCases) { shortcut in
                            Text(shortcut.localizedName).tag(shortcut)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }

                settingsRow(L10n.text("settings.row.microphone"), help: L10n.text("settings.help.microphone")) {
                    Picker("", selection: selectedMicrophoneBinding) {
                        ForEach(model.microphoneOptions) { option in
                            Text(option.localizedName).tag(option.id)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }
            .disabled(!model.config.voiceInput.isEnabled)
        }
    }

    @ViewBuilder
    private var dictationModelRow: some View {
        let dictationModel = model.dictationModel

        settingsRow(L10n.text("settings.row.dictationModel"), help: L10n.text("settings.help.dictationModel")) {
            Text(dictationModel.displayName)
                .font(InkletTheme.Typography.body)
                .foregroundStyle(InkletTheme.secondaryLabel)
                .fixedSize()
        }

        modelStatusRow(detail: L10n.format("settings.dictationModel.detail", dictationModel.localizedDownloadSize)) {
            modelDownloadControls(
                state: model.dictationModelState,
                download: { model.downloadDictationModel() },
                cancel: { model.cancelDictationModelDownload() },
                delete: { model.deleteDictationModel() }
            )
        }
    }

    private var openAIDictationAdvancedSettings: some View {
        DisclosureGroup {
            settingsGroup {
                settingsRow(
                    L10n.text("settings.row.fallbackSpeechModel"),
                    help: L10n.text("settings.help.fallbackSpeechModel")
                ) {
                    TextField(
                        VoiceInputConfig.defaultSpeechModel,
                        text: $model.config.voiceInput.speechModel
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: SettingsLayoutMetrics.fieldWidth)
                }
            }
            .padding(.top, InkletTheme.Spacing.xs)
        } label: {
            Text(L10n.text("settings.group.dictationAdvanced"))
                .font(InkletTheme.Typography.control)
                .foregroundStyle(InkletTheme.secondaryLabel)
        }
        .tint(InkletTheme.secondaryLabel)
    }

    private var selectionActionsPanel: some View {
        VStack(alignment: .leading, spacing: InkletTheme.Spacing.xl) {
            settingsGroup {
                settingsRow(
                    L10n.text("settings.row.selectionActionsEnabled"),
                    help: L10n.text("settings.help.selectionActionsEnabled")
                ) {
                    Toggle("", isOn: $model.config.selectionActions.isEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }

            selectionMenuGroup
            selectionTranslationGroup
            selectionPronunciationGroup
        }
    }

    private var selectionMenuGroup: some View {
        settingsGroup(L10n.text("settings.group.selectionMenu")) {
            settingsStackedRow(
                L10n.text("settings.row.selectionMenuButtons"),
                help: L10n.format(
                    "settings.help.selectionMenuButtons",
                    SelectionMenuLayout.maximumInlineButtonCount
                )
            ) {
                let buttons = model.selectionMenuButtons
                VStack(spacing: 0) {
                    ForEach(Array(buttons.enumerated()), id: \.element.id) { index, button in
                        selectionMenuButtonRow(button, index: index, count: buttons.count)
                        if index < buttons.count - 1 {
                            InkletRowDivider()
                        }
                    }
                }
                .inkletCard(cornerRadius: InkletTheme.Radius.control)
            } accessory: {
                restoreDefaultButton(L10n.text("settings.selectionMenu.restoreDefault")) {
                    model.resetSelectionMenuButtons()
                }
            }

            settingsRow(
                L10n.text("settings.row.forceSelectionMode"),
                help: L10n.text("settings.help.forceSelectionMode")
            ) {
                Picker("", selection: $model.config.selectionActions.forceSelectionMode) {
                    ForEach(SelectionForceSelectionMode.settingsCases) { mode in
                        Text(mode.localizedDisplayName).tag(mode)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }

            settingsRow(
                L10n.text("settings.row.allowSimulatedCopyFallback"),
                help: L10n.text("settings.help.allowSimulatedCopyFallback")
            ) {
                Toggle("", isOn: $model.config.selectionActions.allowsSimulatedCopyFallback)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .disabled(model.config.selectionActions.forceSelectionMode == .disabled)
            }
        }
    }

    private var selectionTranslationGroup: some View {
        settingsGroup(L10n.text("settings.group.translation")) {
            engineNoteRow(textEngineNote, warning: textEngineKeyWarning)

            settingsRow(
                L10n.text("settings.row.translationLanguage"),
                help: L10n.text("settings.help.translationLanguage")
            ) {
                Picker("", selection: $model.config.selectionActions.translationLanguage) {
                    ForEach(SelectionTranslationLanguage.allCases) { language in
                        Text(language.localizedDisplayName).tag(language)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }

            settingsStackedRow(
                L10n.text("settings.row.translationPrompt"),
                help: L10n.text("settings.help.translationPrompt")
            ) {
                SettingsPromptTextView(text: $model.config.selectionActions.translationPrompt)
                    .frame(height: 118)
                    .padding(InkletTheme.Spacing.xs)
                    .modifier(InkletFieldModifier())
                    .accessibilityLabel(L10n.text("settings.row.translationPrompt"))
            } accessory: {
                restoreDefaultButton(L10n.text("settings.translationPrompt.restoreDefault")) {
                    model.resetSelectionTranslationPrompt()
                }
            }
        }
    }

    private var selectionPronunciationGroup: some View {
        settingsGroup(L10n.text("settings.group.pronunciation")) {
            engineNoteRow(
                model.config.selectionActions.pronunciationEngine.localizedName,
                warning: openAIKeyWarning(isNeeded: usesOpenAIPronunciation)
            )

            settingsRow(
                L10n.text(usesOpenAIPronunciation ? "settings.row.aiPronunciation" : "settings.row.systemPronunciationVoice"),
                help: L10n.text(usesOpenAIPronunciation ? "settings.help.aiPronunciation" : "settings.help.systemPronunciationVoice")
            ) {
                HStack(spacing: InkletTheme.Spacing.xxs) {
                    Button {
                        model.previewPronunciationVoice()
                    } label: {
                        switch model.pronunciationPreviewState {
                        case .loading(let voice) where voice == model.config.selectionActions.pronunciationVoice:
                            ProgressView()
                                .controlSize(.small)
                        case .playing(let voice) where voice == model.config.selectionActions.pronunciationVoice:
                            SpeakerWaveIcon(
                                state: .playing,
                                fontSize: InkletTheme.IconSize.regular,
                                weight: .medium,
                                foregroundColor: InkletTheme.accentText
                            )
                        default:
                            SpeakerWaveIcon(
                                state: .idle,
                                fontSize: InkletTheme.IconSize.regular,
                                weight: .medium,
                                foregroundColor: InkletTheme.secondaryLabel
                            )
                        }
                    }
                    .buttonStyle(InkletIconButtonStyle(isActive: isPronunciationPreviewPlaying))
                    .help(L10n.text("settings.aiPronunciation.preview"))
                    .accessibilityLabel(L10n.text("settings.aiPronunciation.preview"))
                    .disabled(model.pronunciationPreviewState?.matches(model.config.selectionActions.pronunciationVoice) == true)

                    if usesOpenAIPronunciation {
                        Picker("", selection: $model.config.selectionActions.pronunciationVoice) {
                            ForEach(SelectionPronunciationVoice.allCases) { voice in
                                Text(voice.displayName).tag(voice)
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                    } else {
                        Text(L10n.text("settings.systemPronunciationVoice.automatic"))
                            .font(InkletTheme.Typography.body)
                            .foregroundStyle(InkletTheme.secondaryLabel)
                            .fixedSize()
                    }
                }
            }

            settingsRow(
                L10n.text("settings.row.aiPronunciationSpeed"),
                help: L10n.text("settings.help.aiPronunciationSpeed")
            ) {
                HStack(spacing: InkletTheme.Spacing.sm) {
                    Slider(
                        value: pronunciationSpeedBinding,
                        in: SelectionActionsConfig.minimumPronunciationSpeed...SelectionActionsConfig.maximumPronunciationSpeed,
                        step: 0.05
                    )
                    .frame(width: 160)

                    Text(pronunciationSpeedText)
                        .font(InkletTheme.Typography.body.monospacedDigit())
                        .foregroundStyle(InkletTheme.secondaryLabel)
                        .frame(width: 44, alignment: .trailing)
                }
            }
        }
    }

    private var historyPanel: some View {
        VStack(alignment: .leading, spacing: InkletTheme.Spacing.md) {
            HStack(spacing: InkletTheme.Spacing.sm) {
                Picker("", selection: $model.historyFilter) {
                    Text(L10n.text("settings.history.filter.all")).tag(Optional<HistorySource>.none)
                    ForEach(HistorySource.allCases) { source in
                        Text(historySourceTitle(source)).tag(Optional(source))
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()

                Spacer()

                Button {
                    isConfirmingClearHistory = true
                } label: {
                    Label(L10n.text("settings.history.clear"), systemImage: "trash")
                }
                .buttonStyle(InkletButtonStyle(kind: .secondary, size: .small))
                .fixedSize()
                .disabled(model.historyItems.isEmpty)
            }
            .padding(.horizontal, InkletTheme.Spacing.xl)
            .padding(.top, InkletTheme.Spacing.xxs)

            if model.filteredHistoryItems.isEmpty {
                VStack(spacing: InkletTheme.Spacing.xs) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(InkletTheme.Typography.pageTitle)
                        .foregroundStyle(InkletTheme.tertiaryLabel)
                    Text(L10n.text("settings.history.empty"))
                        .font(InkletTheme.Typography.body)
                        .foregroundStyle(InkletTheme.secondaryLabel)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: InkletTheme.Spacing.sm) {
                        ForEach(model.filteredHistoryItems) { item in
                            historyRow(item)
                        }
                    }
                    .padding(.horizontal, InkletTheme.Spacing.xl)
                    .padding(.bottom, InkletTheme.Spacing.xl)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            model.reloadHistory()
        }
        .onDisappear {
            historyCopyFeedbackTask?.cancel()
            historyCopyFeedbackTask = nil
            copiedHistoryControlID = nil
        }
    }

    private var promptModesPanel: some View {
        HStack(alignment: .top, spacing: InkletTheme.Spacing.md) {
            VStack(spacing: InkletTheme.Spacing.xs) {
                PromptModeTableView(
                    modes: model.orderedPromptModes,
                    languages: model.config.promptLanguages,
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
                .padding(.vertical, InkletTheme.Spacing.xxs)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: InkletTheme.Radius.card))
                .inkletCard()

                Button {
                    model.addPromptMode()
                } label: {
                    Label(L10n.text("settings.mode.add"), systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(InkletButtonStyle(kind: .secondary))
            }
            .frame(width: SettingsLayoutMetrics.promptModeListWidth)
            .frame(maxHeight: .infinity, alignment: .top)

            if let index = model.selectedPromptModeIndex {
                ScrollView {
                    promptModeDetail(index: index)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)
            } else {
                Text(L10n.text("settings.mode.pick"))
                    .font(InkletTheme.Typography.body)
                    .foregroundStyle(InkletTheme.secondaryLabel)
                    .frame(maxWidth: .infinity, minHeight: 280)
            }
        }
        .padding(.horizontal, InkletTheme.Spacing.xl)
        .padding(.top, InkletTheme.Spacing.xxs)
        .padding(.bottom, InkletTheme.Spacing.xl)
    }

    private func promptModeDetail(index: Int) -> some View {
        VStack(alignment: .leading, spacing: InkletTheme.Spacing.xl) {
            settingsGroup {
                settingsStackedRow(L10n.text("settings.row.name"), help: L10n.text("settings.help.name")) {
                    TextField(L10n.text("settings.row.name"), text: model.promptModeNameBinding(modeID: model.config.promptModes[index].id))
                        .textFieldStyle(.plain)
                        .font(InkletTheme.Typography.body)
                        .padding(.horizontal, InkletTheme.Spacing.xs)
                        .frame(height: InkletTheme.ControlHeight.regular)
                        .modifier(InkletFieldModifier())
                }

                settingsStackedRow(L10n.text("settings.row.systemPrompt"), help: L10n.text("settings.help.systemPrompt")) {
                    SettingsPromptTextView(text: $model.config.promptModes[index].systemPrompt)
                        .frame(height: 188)
                        .padding(InkletTheme.Spacing.xs)
                        .modifier(InkletFieldModifier())
                        .accessibilityLabel(L10n.text("settings.row.systemPrompt"))
                }
            }

            settingsGroup {
                settingsRow(
                    L10n.text("settings.mode.visibleInMenu"),
                    help: L10n.text("settings.mode.visibleInMenuHelp")
                ) {
                    Toggle("", isOn: model.promptModeVisibilityBinding(modeID: model.config.promptModes[index].id))
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }
        }
    }

    private var systemPermissionsPanel: some View {
        settingsGroup(L10n.text("settings.systemPermissions.title")) {
            permissionLine(
                title: L10n.text("settings.permission.accessibility"),
                description: model.isAccessibilityTrusted
                    ? L10n.text("settings.permission.authorized")
                    : L10n.text("settings.permission.description"),
                isTrusted: model.isAccessibilityTrusted,
                action: { model.openAccessibilitySettings() }
            )
        }
        .id(model.permissionRefreshID)
    }

    private var aboutPanel: some View {
        VStack(alignment: .leading, spacing: InkletTheme.Spacing.xl) {
            settingsAboutSummary

            settingsGroup(L10n.text("settings.quickStart.title")) {
                quickStartShortcuts
            }

            settingsGroup(L10n.text("settings.privacy.title")) {
                privacyLine(L10n.text("settings.privacy.keychain"))
                privacyLine(L10n.text("settings.privacy.provider"))
                privacyLine(L10n.text("settings.privacy.voice"))
                privacyLine(L10n.text("settings.privacy.clipboard"))
                privacyLine(L10n.text("settings.privacy.history"))
            }
        }
        .id(model.permissionRefreshID)
    }

    private var settingsAboutSummary: some View {
        HStack(alignment: .top, spacing: InkletTheme.Spacing.md) {
            PenNibShape()
                .stroke(style: StrokeStyle(lineWidth: 1.45, lineCap: .round, lineJoin: .round))
                .foregroundStyle(InkletTheme.label)
                .padding(10)
                .frame(width: 48, height: 48)
                .background(InkletTheme.fill, in: RoundedRectangle(cornerRadius: InkletTheme.Radius.card))

            VStack(alignment: .leading, spacing: InkletTheme.Spacing.xs) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Inklet")
                        .font(InkletTheme.Typography.title)
                        .foregroundStyle(InkletTheme.label)
                    Text(L10n.format("settings.version", BuildInfo.displayVersion))
                        .font(InkletTheme.Typography.caption)
                        .foregroundStyle(InkletTheme.tertiaryLabel)
                }

                Text(L10n.text("about.tagline"))
                    .font(InkletTheme.Typography.body)
                    .foregroundStyle(InkletTheme.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: InkletTheme.Spacing.md) {
                    Link(L10n.text("about.website"), destination: URL(string: "https://getinklet.app")!)
                    Link(L10n.text("about.privacyPolicy"), destination: URL(string: "https://getinklet.app/privacy")!)
                    Link(L10n.text("about.support"), destination: URL(string: "mailto:support@getinklet.app")!)
                }
                .font(InkletTheme.Typography.control)

                Text("© 2026 Inklet")
                    .font(InkletTheme.Typography.caption)
                    .foregroundStyle(InkletTheme.tertiaryLabel)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(InkletTheme.Spacing.md)
        .inkletCard()
    }

    @ViewBuilder
    private var quickStartShortcuts: some View {
        shortcutLine(keys: [model.config.hotkey], title: L10n.text("settings.quickStart.open"))
        shortcutLine(keys: ["⌘", "↵"], title: L10n.text("settings.quickStart.original"))
        if model.config.voiceInput.activeShortcut != .disabled {
            shortcutLine(keys: voiceShortcutKeys, title: L10n.text("settings.quickStart.voice.pressAndHold"))
        }
        shortcutLine(keys: ["↵"], title: L10n.text("settings.quickStart.submit"))
        shortcutLine(keys: ["esc"], title: L10n.text("settings.quickStart.close"))
    }

    private var voiceShortcutKeys: [String] {
        [model.config.voiceInput.shortcut.localizedName]
    }

    private func permissionStatusColor(isTrusted: Bool) -> Color {
        isTrusted ? InkletTheme.statusSuccess : InkletTheme.statusWarning
    }

    private func shortcutLine(keys: [String], title: String) -> some View {
        VStack(spacing: 0) {
            InkletRowDivider()
            HStack(spacing: InkletTheme.Spacing.md) {
                shortcutTitle(title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                shortcutKeys(keys)
                    .fixedSize()
            }
            .padding(.horizontal, InkletTheme.Spacing.sm)
            .padding(.vertical, InkletTheme.Spacing.xs)
            .frame(minHeight: SettingsLayoutMetrics.compactRowHeight)
        }
    }

    private func shortcutKeys(_ keys: [String]) -> some View {
        HStack(spacing: InkletTheme.Spacing.xxs) {
            ForEach(keys, id: \.self) { key in
                Keycap(title: key)
            }
        }
    }

    private func shortcutTitle(_ title: String) -> some View {
        Text(title)
            .font(InkletTheme.Typography.body)
            .foregroundStyle(InkletTheme.label)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func permissionLine(
        title: String,
        description: String,
        isTrusted: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let statusColor = permissionStatusColor(isTrusted: isTrusted)

        return VStack(spacing: 0) {
            InkletRowDivider()
            HStack(alignment: .center, spacing: InkletTheme.Spacing.sm) {
                Image(systemName: isTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: InkletTheme.IconSize.large, weight: .medium))
                    .foregroundStyle(statusColor)
                    .frame(width: 20)
                    .accessibilityLabel(L10n.text(isTrusted ? "settings.permission.authorized" : "settings.permission.required"))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(InkletTheme.Typography.body)
                        .foregroundStyle(InkletTheme.label)

                    Text(description)
                        .font(InkletTheme.Typography.help)
                        .foregroundStyle(InkletTheme.secondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: action) {
                    Label(L10n.text("settings.permission.openShort"), systemImage: "arrow.up.forward.app")
                }
                .buttonStyle(InkletButtonStyle(kind: .secondary, size: .small))
                .fixedSize()
            }
            .padding(.horizontal, InkletTheme.Spacing.sm)
            .padding(.vertical, InkletTheme.Spacing.sm)
        }
    }

    private func privacyLine(_ text: String) -> some View {
        VStack(spacing: 0) {
            InkletRowDivider()
            Text(text.replacingOccurrences(of: "• ", with: ""))
                .font(InkletTheme.Typography.body)
                .foregroundStyle(InkletTheme.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, InkletTheme.Spacing.sm)
                .padding(.vertical, InkletTheme.Spacing.xs)
                .frame(minHeight: SettingsLayoutMetrics.compactRowHeight)
        }
    }

    private func historyRow(_ item: HistoryItem) -> some View {
        VStack(alignment: .leading, spacing: InkletTheme.Spacing.sm) {
            HStack(spacing: InkletTheme.Spacing.xs) {
                Label(historySourceTitle(item.source), systemImage: historySourceIcon(item.source))
                    .font(InkletTheme.Typography.control)
                    .foregroundStyle(InkletTheme.label)

                Text(item.createdAt.formatted(
                    Date.FormatStyle(date: .abbreviated, time: .shortened)
                        .locale(Locale(identifier: localeIdentifier))
                ))
                    .font(InkletTheme.Typography.caption)
                    .foregroundStyle(InkletTheme.tertiaryLabel)

                if let label = historyMetadataLabel(item) {
                    Text(label)
                        .font(InkletTheme.Typography.caption)
                        .foregroundStyle(InkletTheme.tertiaryLabel)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer()

                historyCopyButton(
                    title: L10n.text("settings.history.copyResult"),
                    text: item.outputText,
                    feedbackID: "\(item.id.uuidString)-output"
                )
            }

            historyTextBlock(title: L10n.text("settings.history.original"), text: item.inputText)
            historyTextBlock(title: L10n.text("settings.history.result"), text: item.outputText)
        }
        .padding(InkletTheme.Spacing.sm)
        .inkletCard()
    }

    private func historyTextBlock(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: InkletTheme.Spacing.xxs) {
            Text(title)
                .font(InkletTheme.Typography.caption)
                .foregroundStyle(InkletTheme.tertiaryLabel)

            ScrollView {
                Text(text)
                    .font(InkletTheme.Typography.body)
                    .foregroundStyle(InkletTheme.label)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxHeight: 86)
        }
    }

    private func historyCopyButton(title: String, text: String, feedbackID: String) -> some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            copiedHistoryControlID = feedbackID
            historyCopyFeedbackTask?.cancel()
            historyCopyFeedbackTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(900))
                guard copiedHistoryControlID == feedbackID else { return }
                copiedHistoryControlID = nil
                historyCopyFeedbackTask = nil
            }
        } label: {
            Image(systemName: copiedHistoryControlID == feedbackID ? "checkmark" : "doc.on.doc")
                .foregroundStyle(copiedHistoryControlID == feedbackID ? InkletTheme.statusSuccess : InkletTheme.secondaryLabel)
        }
        .buttonStyle(InkletIconButtonStyle(size: InkletTheme.ControlHeight.small))
        .help(title)
        .accessibilityLabel(title)
    }

    private func historySourceTitle(_ source: HistorySource) -> String {
        switch source {
        case .write:
            L10n.text("settings.history.source.write")
        case .voice:
            L10n.text("settings.history.source.voice")
        case .selection:
            L10n.text("settings.history.source.selection")
        }
    }

    private func historySourceIcon(_ source: HistorySource) -> String {
        switch source {
        case .write:
            "pencil.and.scribble"
        case .voice:
            "mic"
        case .selection:
            "text.viewfinder"
        }
    }

    private func historyMetadataLabel(_ item: HistoryItem) -> String? {
        if let targetLanguageName = item.targetLanguageName {
            return targetLanguageName
        }
        if let modeName = item.modeName {
            return modeName
        }
        return item.model
    }

    // MARK: Page building blocks (docs/DESIGN.md, Surfaces > Settings)

    /// A scrolling pane with the page margins.
    private func settingsPage<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, InkletTheme.Spacing.xl)
                .padding(.top, InkletTheme.Spacing.xxs)
                .padding(.bottom, InkletTheme.Spacing.xl)
        }
    }

    /// A card of rows with an optional small title above it.
    private func settingsGroup<Content: View>(
        _ title: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: InkletTheme.Spacing.xs) {
            if let title {
                Text(title)
                    .font(InkletTheme.Typography.help.weight(.semibold))
                    .foregroundStyle(InkletTheme.secondaryLabel)
                    .padding(.leading, InkletTheme.Spacing.sm)
            }

            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            // Every row starts with a hairline; the first one tucks under the card's top edge.
            .padding(.top, -1)
            .clipShape(RoundedRectangle(cornerRadius: InkletTheme.Radius.card))
            .inkletCard()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func settingsRowLabel(_ title: String, help: String, warning: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(InkletTheme.Typography.body)
                .foregroundStyle(InkletTheme.label)
                .fixedSize(horizontal: false, vertical: true)
            if !help.isEmpty {
                Text(help)
                    .font(InkletTheme.Typography.help)
                    .foregroundStyle(InkletTheme.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let warning {
                Label(warning, systemImage: "exclamationmark.triangle")
                    .font(InkletTheme.Typography.help)
                    .foregroundStyle(InkletTheme.statusWarning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Label and help on the left, the control on the right.
    private func settingsRow<Content: View>(
        _ title: String,
        help: String = "",
        warning: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            InkletRowDivider()
            HStack(alignment: .center, spacing: InkletTheme.Spacing.md) {
                settingsRowLabel(title, help: help, warning: warning)
                content()
            }
            .padding(.horizontal, InkletTheme.Spacing.sm)
            .padding(.vertical, InkletTheme.Spacing.xs)
            .frame(minHeight: SettingsLayoutMetrics.rowHeight)
        }
    }

    /// Label and help above a control that needs the full width, such as a prompt editor.
    private func settingsStackedRow<Content: View, Accessory: View>(
        _ title: String,
        help: String = "",
        @ViewBuilder content: () -> Content,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        VStack(spacing: 0) {
            InkletRowDivider()
            VStack(alignment: .leading, spacing: InkletTheme.Spacing.xs) {
                HStack(alignment: .top, spacing: InkletTheme.Spacing.md) {
                    settingsRowLabel(title, help: help)
                    accessory()
                }
                content()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(InkletTheme.Spacing.sm)
        }
    }

    private func settingsStackedRow<Content: View>(
        _ title: String,
        help: String = "",
        @ViewBuilder content: () -> Content
    ) -> some View {
        settingsStackedRow(title, help: help, content: content) {
            EmptyView()
        }
    }

    private func restoreDefaultButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: "arrow.counterclockwise")
        }
        .buttonStyle(InkletButtonStyle(kind: .ghost, size: .small))
        .fixedSize()
        .help(title)
        .accessibilityLabel(title)
    }

    private func selectionMenuButtonRow(_ button: SelectionMenuButton, index: Int, count: Int) -> some View {
        let item = model.selectionMenuItem(for: button)
        return HStack(spacing: InkletTheme.Spacing.xs) {
            Toggle(isOn: Binding(
                get: { button.isEnabled },
                set: { model.setSelectionMenuButton(button.action, isEnabled: $0) }
            )) {
                HStack(spacing: InkletTheme.Spacing.xs) {
                    Image(systemName: item.systemImage)
                        .font(.system(size: InkletTheme.IconSize.small, weight: .medium))
                        .foregroundStyle(InkletTheme.secondaryLabel)
                        .frame(width: InkletTheme.IconSize.large)
                    Text(item.title)
                        .font(InkletTheme.Typography.body)
                        .foregroundStyle(InkletTheme.label)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .toggleStyle(.checkbox)
            .disabled(!model.canDisableSelectionMenuButton(button))

            Spacer(minLength: InkletTheme.Spacing.xs)

            selectionMenuMoveButton(
                title: L10n.text("settings.selectionMenu.moveUp"),
                systemImage: "chevron.up",
                isEnabled: index > 0
            ) {
                model.moveSelectionMenuButton(at: index, by: -1)
            }
            selectionMenuMoveButton(
                title: L10n.text("settings.selectionMenu.moveDown"),
                systemImage: "chevron.down",
                isEnabled: index < count - 1
            ) {
                model.moveSelectionMenuButton(at: index, by: 1)
            }
        }
        .padding(.leading, InkletTheme.Spacing.sm)
        .padding(.trailing, InkletTheme.Spacing.xxs)
        .frame(minHeight: SettingsLayoutMetrics.compactRowHeight)
    }

    private func selectionMenuMoveButton(
        title: String,
        systemImage: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
        }
        .buttonStyle(InkletIconButtonStyle(size: InkletTheme.ControlHeight.small))
        .disabled(!isEnabled)
        .help(title)
        .accessibilityLabel(title)
    }
}

struct SettingsSidebarLabel: View {
    let section: SettingsSection
    let isSelected: Bool
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: InkletTheme.Spacing.xs) {
            Image(systemName: section.icon)
                .font(.system(size: InkletTheme.IconSize.regular, weight: .medium))
                .foregroundStyle(isSelected ? InkletTheme.accentText : InkletTheme.secondaryLabel)
                .frame(width: SettingsLayoutMetrics.sidebarIconWidth)
            Text(section.title)
                .font(InkletTheme.Typography.body.weight(isSelected ? .medium : .regular))
                .foregroundStyle(InkletTheme.label)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, InkletTheme.Spacing.xs)
        .padding(.vertical, SettingsLayoutMetrics.sidebarItemVerticalPadding)
        .frame(minHeight: SettingsLayoutMetrics.sidebarItemHeight)
        .background(background, in: RoundedRectangle(cornerRadius: InkletTheme.Radius.small))
        .contentShape(RoundedRectangle(cornerRadius: InkletTheme.Radius.small))
        .onHover { isHovered = $0 }
        .animation(InkletTheme.Motion.fast, value: isHovered)
    }

    private var background: Color {
        // A neutral selection; only the icon carries the accent (docs/DESIGN.md, Refinement rules).
        if isSelected {
            return InkletTheme.fillHover
        }
        return isHovered ? InkletTheme.fill : .clear
    }
}

enum SettingsLayoutMetrics {
    static let sidebarWidth: CGFloat = 210
    static let sidebarItemHeight: CGFloat = 30
    static let sidebarItemVerticalPadding: CGFloat = 6
    static let sidebarIconWidth: CGFloat = 18
    /// Clears the system traffic lights in the transparent titlebar.
    static let titlebarInset: CGFloat = 52
    static let headerHeight: CGFloat = 68
    static let rowHeight: CGFloat = 44
    static let compactRowHeight: CGFloat = 36
    static let fieldWidth: CGFloat = 220
    static let promptModeListWidth: CGFloat = 240

    static var migrationActionWidth: CGFloat {
        let font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        let titles = [
            "legacyMigration.action.importOldData",
            "legacyMigration.import.progress",
            "legacyMigration.import.relaunchProgress",
            "legacyMigration.action.retryRelaunch"
        ]
        let textWidth = titles.map {
            (L10n.text($0) as NSString).size(withAttributes: [.font: font]).width
        }.max() ?? 0
        return max(168, ceil(textWidth) + 22)
    }
}
