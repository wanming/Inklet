import AppKit
import SwiftUI
import InkletCore

private extension SelectionTranslationLanguage {
    var localizedDisplayName: String {
        switch self {
        case .followInterfaceLanguage: L10n.text("selection.language.followInterface")
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        case .japanese: "日本語"
        case .korean: "한국어"
        case .spanish: "Español"
        case .french: "Français"
        case .german: "Deutsch"
        case .portuguese: "Português"
        case .italian: "Italiano"
        }
    }
}

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

enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General"
    case writeAssistant = "Write Assistant"
    case selectionAssistant = "Selection Assistant"
    case history = "History"
    case promptModes = "Prompt Modes"
    case about = "About"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: L10n.text("settings.section.general")
        case .writeAssistant: L10n.text("settings.section.writeAssistant")
        case .selectionAssistant: L10n.text("settings.section.selectionAssistant")
        case .history: L10n.text("settings.section.history")
        case .promptModes: L10n.text("settings.section.promptModes")
        case .about: L10n.text("settings.section.about")
        }
    }

    var icon: String {
        switch self {
        case .general: "gearshape"
        case .writeAssistant: "pencil.and.scribble"
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

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            detail
        }
        .frame(width: 860, height: 560)
        .environment(\.locale, Locale(identifier: localeIdentifier))
        .background(InkletTheme.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(InkletTheme.strongBorder)
        }
        .shadow(color: .black.opacity(0.75), radius: 48, x: 0, y: 28)
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
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 10) {
                    PenNibShape()
                        .stroke(style: StrokeStyle(lineWidth: 1.45, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(InkletTheme.primary)
                        .padding(6)
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
                        SettingsSidebarLabel(
                            section: section,
                            isSelected: selectedSection == section
                        )
                    }
                    .buttonStyle(.plain)
                    .help(section.title)
                }
            }
            .padding(.horizontal, 8)

            Spacer()
            Text(L10n.format("settings.version", BuildInfo.displayVersion))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(InkletTheme.textFaint)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 188)
        .disabled(model.isMigrationMaintenanceActive)
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
                case .writeAssistant:
                    writeAssistantPanel
                        .disabled(model.isMigrationMaintenanceActive)
                case .selectionAssistant:
                    ScrollView {
                        selectionActionsPanel
                            .padding(.horizontal, 24)
                            .padding(.vertical, 20)
                    }
                    .disabled(model.isMigrationMaintenanceActive)
                case .history:
                    historyPanel
                        .disabled(model.isMigrationMaintenanceActive)
                case .promptModes:
                    promptModesPanel
                        .disabled(model.isMigrationMaintenanceActive)
                case .about:
                    ScrollView {
                        aboutPanel
                            .padding(.horizontal, 24)
                            .padding(.vertical, 20)
                    }
                    .disabled(model.isMigrationMaintenanceActive)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

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
            .help(L10n.text("popover.hint.close"))
            .accessibilityLabel(L10n.text("popover.hint.close"))
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 15)
    }

    private var sectionDescription: String {
        switch selectedSection {
        case .general:
            L10n.text("settings.description.general")
        case .writeAssistant:
            L10n.text("settings.description.writeAssistant")
        case .selectionAssistant:
            L10n.text("settings.description.selectionAssistant")
        case .history:
            L10n.text("settings.description.history")
        case .promptModes:
            L10n.text("settings.description.promptModes")
        case .about:
            L10n.text("settings.description.about")
        }
    }

    private var generalPanel: some View {
        VStack(alignment: .leading, spacing: 22) {
            if migrationPresentationModel.phase != .hidden {
                migrationNoticeCard
            }

            VStack(alignment: .leading, spacing: 22) {
                settingsPanel {
                    settingsRow(L10n.text("settings.row.openAIAPIKey"), help: L10n.text("settings.help.openAIAPIKey")) {
                        SecureField(LLMProviderPreset.openAI.apiKeyPlaceholder, text: $model.providerAPIKey)
                            .textFieldStyle(.roundedBorder)
                    }

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
                }

                systemPermissionsPanel
            }
            .disabled(model.isMigrationMaintenanceActive)
        }
    }

    private var migrationNoticeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "externaldrive.badge.exclamationmark")
                    .foregroundStyle(InkletTheme.warning)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.text("legacyMigration.notice.title"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(InkletTheme.textPrimary)
                    Text(migrationNoticeMessage)
                        .font(.system(size: 11))
                        .foregroundStyle(InkletTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                migrationPrimaryAction
                if migrationPresentationModel.phase == .relaunchFailed {
                    Button(L10n.text("legacyMigration.action.quit"), action: onQuitForMigration)
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(InkletTheme.textSecondary)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(InkletTheme.controlFill, in: RoundedRectangle(cornerRadius: 7))
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(14)
        .frame(maxWidth: 580, alignment: .leading)
        .background(InkletTheme.controlFill.opacity(0.58), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(InkletTheme.subtleBorder)
        }
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
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .disabled(!isEnabled)
        .help(L10n.text("legacyMigration.settings.help"))
        .accessibilityLabel(L10n.text(titleKey))
    }

    private var writeAssistantControls: some View {
        let selectedModelBinding = Binding(
            get: { model.selectedModelMenuValue },
            set: { model.selectModelMenuValue($0) }
        )

        return settingsPanel {
            settingsRow(L10n.text("settings.row.hotkey"), help: L10n.text("settings.help.hotkey")) {
                HotkeyRecorderField(hotkey: $model.config.hotkey)
                    .frame(width: 220, height: 34)
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

            settingsRow(L10n.text("settings.row.timeout"), help: L10n.text("settings.help.timeout")) {
                Stepper(value: $model.config.timeoutSeconds, in: 1...120, step: 1) {
                    Text(L10n.format("settings.seconds", Int(model.config.timeoutSeconds)))
                        .font(.body.monospacedDigit())
                }
            }
        }
    }

    private var writingSettingsPanel: some View {
        writeAssistantControls
    }

    private var writeAssistantPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                settingsGroupTitle(
                    L10n.text("settings.group.writing"),
                    help: L10n.text("settings.group.writing.help")
                )
                writingSettingsPanel

                settingsGroupTitle(
                    L10n.text("settings.group.dictation"),
                    help: L10n.text("settings.group.dictation.help")
                )
                dictationSettingsPanel
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
    }

    private var dictationSettingsPanel: some View {
        let selectedMicrophoneBinding = Binding(
            get: { model.selectedMicrophoneMenuID },
            set: { model.selectedMicrophoneMenuID = $0 }
        )

        return settingsPanel {
            settingsRow(
                L10n.text("settings.row.dictationShortcut"),
                help: L10n.text("settings.help.dictationShortcut")
            ) {
                Picker("", selection: $model.config.voiceInput.shortcut) {
                    ForEach(VoiceInputConfig.Shortcut.allCases) { shortcut in
                        Text(shortcut.localizedName).tag(shortcut)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 320, alignment: .leading)
            }

            settingsRow(L10n.text("settings.row.microphone"), help: L10n.text("settings.help.microphone")) {
                Picker("", selection: selectedMicrophoneBinding) {
                    ForEach(model.microphoneOptions) { option in
                        Text(option.localizedName).tag(option.id)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 320, alignment: .leading)
            }

            DisclosureGroup {
                VStack(alignment: .leading, spacing: 12) {
                    settingsRow(
                        L10n.text("settings.row.fallbackSpeechModel"),
                        help: L10n.text("settings.help.fallbackSpeechModel")
                    ) {
                        TextField(
                            VoiceInputConfig.defaultSpeechModel,
                            text: $model.config.voiceInput.speechModel
                        )
                        .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(.top, 10)
            } label: {
                Text(L10n.text("settings.group.dictationAdvanced"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(InkletTheme.textPrimary)
            }
            .tint(InkletTheme.textSecondary)
        }
    }

    private var selectionActionsPanel: some View {
        settingsPanel {
            settingsRow(
                L10n.text("settings.row.selectionActionsEnabled"),
                help: L10n.text("settings.help.selectionActionsEnabled")
            ) {
                Toggle("", isOn: $model.config.selectionActions.isEnabled)
                    .labelsHidden()
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
                .frame(maxWidth: 320, alignment: .leading)
            }

            settingsRow(
                L10n.text("settings.row.allowSimulatedCopyFallback"),
                help: L10n.text("settings.help.allowSimulatedCopyFallback")
            ) {
                Toggle("", isOn: $model.config.selectionActions.allowsSimulatedCopyFallback)
                    .labelsHidden()
                    .disabled(model.config.selectionActions.forceSelectionMode == .disabled)
            }

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
                .frame(maxWidth: 320, alignment: .leading)
            }

            settingsRow(
                L10n.text("settings.row.translationPrompt"),
                help: L10n.text("settings.help.translationPrompt")
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    SettingsPromptTextView(text: $model.config.selectionActions.translationPrompt)
                        .frame(height: 118)
                        .padding(10)
                        .modifier(InkletFieldModifier())
                        .accessibilityLabel(L10n.text("settings.row.translationPrompt"))

                    Button {
                        model.resetSelectionTranslationPrompt()
                    } label: {
                        Label(
                            L10n.text("settings.translationPrompt.restoreDefault"),
                            systemImage: "arrow.counterclockwise"
                        )
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(InkletTheme.textSecondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(InkletTheme.controlFill, in: RoundedRectangle(cornerRadius: 7))
                    .fixedSize()
                    .help(L10n.text("settings.translationPrompt.restoreDefault"))
                    .accessibilityLabel(L10n.text("settings.translationPrompt.restoreDefault"))
                }
                .frame(maxWidth: 420, alignment: .leading)
            }

            settingsRow(
                L10n.text("settings.row.aiPronunciation"),
                help: L10n.text("settings.help.aiPronunciation")
            ) {
                HStack(spacing: 8) {
                    Picker("", selection: $model.config.selectionActions.pronunciationVoice) {
                        ForEach(SelectionPronunciationVoice.allCases) { voice in
                            Text(voice.displayName).tag(voice)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 220, alignment: .leading)

                    Button {
                        model.previewPronunciationVoice()
                    } label: {
                        switch model.pronunciationPreviewState {
                        case .loading(let voice) where voice == model.config.selectionActions.pronunciationVoice:
                            ProgressView()
                                .controlSize(.small)
                                .frame(width: 18, height: 18)
                        case .playing(let voice) where voice == model.config.selectionActions.pronunciationVoice:
                            SpeakerWaveIcon(state: .playing, fontSize: 13, weight: .regular)
                                .frame(width: 18, height: 18)
                        default:
                            SpeakerWaveIcon(state: .idle, fontSize: 13, weight: .regular)
                                .frame(width: 18, height: 18)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help(L10n.text("settings.aiPronunciation.preview"))
                    .accessibilityLabel(L10n.text("settings.aiPronunciation.preview"))
                    .disabled(model.pronunciationPreviewState?.matches(model.config.selectionActions.pronunciationVoice) == true)
                }
                .fixedSize(horizontal: true, vertical: false)
                .frame(maxWidth: 320, alignment: .leading)
            }

            settingsRow(
                L10n.text("settings.row.aiPronunciationSpeed"),
                help: L10n.text("settings.help.aiPronunciationSpeed")
            ) {
                HStack(spacing: 12) {
                    Slider(
                        value: pronunciationSpeedBinding,
                        in: SelectionActionsConfig.minimumPronunciationSpeed...SelectionActionsConfig.maximumPronunciationSpeed,
                        step: 0.05
                    )
                    .frame(maxWidth: 220)

                    Text(pronunciationSpeedText)
                        .font(.body.monospacedDigit())
                        .frame(width: 52, alignment: .trailing)
                }
                .frame(maxWidth: 320, alignment: .leading)
            }
        }
    }

    private var historyPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Picker("", selection: $model.historyFilter) {
                    Text(L10n.text("settings.history.filter.all")).tag(Optional<HistorySource>.none)
                    ForEach(HistorySource.allCases) { source in
                        Text(historySourceTitle(source)).tag(Optional(source))
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)
                .labelsHidden()

                Spacer()

                Button {
                    isConfirmingClearHistory = true
                } label: {
                    Label(L10n.text("settings.history.clear"), systemImage: "trash")
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(InkletTheme.warning)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(InkletTheme.controlFill, in: RoundedRectangle(cornerRadius: 7))
                .disabled(model.historyItems.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            if model.filteredHistoryItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(InkletTheme.textFaint)
                    Text(L10n.text("settings.history.empty"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(InkletTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(model.filteredHistoryItems) { item in
                            historyRow(item)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
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

    private var systemPermissionsPanel: some View {
        VStack(alignment: .leading, spacing: 22) {
            permissionSection(title: L10n.text("settings.systemPermissions.title")) {
                permissionLine(
                    title: L10n.text("settings.permission.accessibility"),
                    description: L10n.text("settings.permission.description"),
                    isTrusted: model.isAccessibilityTrusted,
                    action: { model.openAccessibilitySettings() }
                )
            }
        }
        .frame(maxWidth: 680, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .id(model.permissionRefreshID)
    }

    private var aboutPanel: some View {
        VStack(alignment: .leading, spacing: 22) {
            settingsAboutSummary

            permissionSection(title: L10n.text("settings.quickStart.title")) {
                quickStartShortcuts
            }

            permissionSection(title: L10n.text("settings.privacy.title")) {
                VStack(alignment: .leading, spacing: 8) {
                    privacyLine(L10n.text("settings.privacy.keychain"))
                    privacyLine(L10n.text("settings.privacy.provider"))
                    privacyLine(L10n.text("settings.privacy.voice"))
                    privacyLine(L10n.text("settings.privacy.clipboard"))
                    privacyLine(L10n.text("settings.privacy.history"))
                }
            }
        }
        .frame(maxWidth: 680, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .id(model.permissionRefreshID)
    }

    private var settingsAboutSummary: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                PenNibShape()
                    .stroke(style: StrokeStyle(lineWidth: 1.45, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(InkletTheme.primary)
                    .padding(10)
                    .frame(width: 48, height: 48)
                    .background(InkletTheme.primary.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(InkletTheme.primary.opacity(0.20))
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Inklet")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(InkletTheme.textPrimary)
                    Text(L10n.format("settings.version", BuildInfo.displayVersion))
                        .font(.system(size: 11))
                        .foregroundStyle(InkletTheme.textTertiary)
                }
            }

            Text(L10n.text("about.tagline"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(InkletTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                Link(L10n.text("about.website"), destination: URL(string: "https://getinklet.app")!)
                Link(L10n.text("about.privacyPolicy"), destination: URL(string: "https://getinklet.app/privacy")!)
                Link(L10n.text("about.support"), destination: URL(string: "mailto:support@getinklet.app")!)
            }
            .font(.system(size: 12, weight: .medium))

            Text("© 2026 Inklet")
                .font(.system(size: 11))
                .foregroundStyle(InkletTheme.textTertiary)
        }
        .padding(14)
        .frame(maxWidth: 680, alignment: .leading)
        .background(InkletTheme.controlFill, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(InkletTheme.subtleBorder)
        }
    }

    private var quickStartShortcuts: some View {
        HStack(alignment: .top, spacing: 48) {
            VStack(alignment: .leading, spacing: 8) {
                shortcutLine(keys: [model.config.hotkey], title: L10n.text("settings.quickStart.open"), keyWidth: 102, keyAlignment: .trailing)
                shortcutLine(keys: ["⌘", "↵"], title: L10n.text("settings.quickStart.original"), keyWidth: 102, keyAlignment: .trailing)
                if model.config.voiceInput.shortcut != .disabled {
                    shortcutLine(
                        keys: voiceShortcutKeys,
                        title: L10n.text("settings.quickStart.voice.pressAndHold"),
                        keyWidth: 102,
                        keyAlignment: .trailing
                    )
                }
            }
            .frame(width: 292, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                shortcutLine(keys: ["↵"], title: L10n.text("settings.quickStart.submit"), keyWidth: 34, keyAlignment: .leading, textSpacing: 8)
                shortcutLine(keys: ["esc"], title: L10n.text("settings.quickStart.close"), keyWidth: 34, keyAlignment: .leading, textSpacing: 8)
            }
            .frame(width: 220, alignment: .leading)
        }
        .frame(width: 560, alignment: .leading)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var voiceShortcutKeys: [String] {
        [model.config.voiceInput.shortcut.localizedName]
    }

    private func permissionStatusColor(isTrusted: Bool) -> Color {
        isTrusted ? InkletTheme.primary : InkletTheme.warning
    }

    private func permissionSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.7)
                .textCase(.uppercase)
                .foregroundStyle(InkletTheme.textTertiary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func shortcutLine(keys: [String], title: String, keyWidth: CGFloat, keyAlignment: Alignment, textSpacing: CGFloat = 14) -> some View {
        HStack(spacing: textSpacing) {
            shortcutKeys(keys)
                .fixedSize()
                .frame(minWidth: keyWidth, alignment: keyAlignment)

            shortcutTitle(title)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func shortcutKeys(_ keys: [String]) -> some View {
        HStack(spacing: 4) {
            ForEach(keys, id: \.self) { key in
                Keycap(title: key)
            }
        }
    }

    private func shortcutTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12))
            .foregroundStyle(InkletTheme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func permissionLine(
        title: String,
        description: String,
        isTrusted: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let statusColor = permissionStatusColor(isTrusted: isTrusted)

        return HStack(alignment: .center, spacing: 14) {
            Image(systemName: isTrusted ? "checkmark" : "exclamationmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(statusColor)
                .frame(width: 42, height: 42)
                .background(statusColor.opacity(0.11), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(InkletTheme.textPrimary)
                }

                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(InkletTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: action) {
                Label(L10n.text("settings.permission.openShort"), systemImage: "arrow.up.forward.app")
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(InkletTheme.textSecondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(InkletTheme.controlFill, in: RoundedRectangle(cornerRadius: 7))
            .fixedSize()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InkletTheme.controlFill.opacity(0.58), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(InkletTheme.subtleBorder)
        }
    }

    private func privacyLine(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle()
                .fill(InkletTheme.textFaint)
                .frame(width: 3, height: 3)
                .alignmentGuide(.firstTextBaseline) { context in
                    context[VerticalAlignment.center]
                }
            Text(text.replacingOccurrences(of: "• ", with: ""))
                .font(.system(size: 12))
                .foregroundStyle(InkletTheme.textSecondary)
        }
    }

    private func historyRow(_ item: HistoryItem) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Label(historySourceTitle(item.source), systemImage: historySourceIcon(item.source))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(InkletTheme.textPrimary)

                Text(item.createdAt.formatted(
                    Date.FormatStyle(date: .abbreviated, time: .shortened)
                        .locale(Locale(identifier: localeIdentifier))
                ))
                    .font(.system(size: 11))
                    .foregroundStyle(InkletTheme.textTertiary)

                if let label = historyMetadataLabel(item) {
                    Text(label)
                        .font(.system(size: 11))
                        .foregroundStyle(InkletTheme.textTertiary)
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
        .padding(12)
        .background(InkletTheme.controlFill.opacity(0.58), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(InkletTheme.subtleBorder)
        }
    }

    private func historyTextBlock(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(InkletTheme.textTertiary)

            ScrollView {
                Text(text)
                    .font(.system(size: 12))
                    .foregroundStyle(InkletTheme.textSecondary)
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
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(InkletTheme.textSecondary)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

    private var footer: some View {
        HStack(spacing: 12) {
            if !model.message.isEmpty {
                Label(model.message, systemImage: isSuccessMessage ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(isSuccessMessage ? InkletTheme.success : .red)
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

    private func settingsGroupTitle(_ title: String, help: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(InkletTheme.textPrimary)
            Text(help)
                .font(.system(size: 11))
                .foregroundStyle(InkletTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
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

struct SettingsSidebarLabel: View {
    let section: SettingsSection
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: section.icon)
                .frame(width: 18)
            Text(section.title)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
        .foregroundStyle(isSelected ? InkletTheme.primary.opacity(0.95) : InkletTheme.textSecondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            isSelected ? InkletTheme.primary.opacity(0.12) : Color.clear,
            in: RoundedRectangle(cornerRadius: 12)
        )
    }
}

enum SettingsLayoutMetrics {
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
