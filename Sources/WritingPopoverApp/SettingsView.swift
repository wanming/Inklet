import AppKit
import Carbon
import Combine
import SwiftUI
import WritingPopoverCore

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var config: AppConfig
    @Published var message: String
    @Published var providerAPIKeys: [String: String]
    @Published var selectedPromptModeID: String
    @Published var interfaceLanguage: InterfaceLanguage

    private let configStore: UserDefaultsConfigStore

    init(configStore: UserDefaultsConfigStore = UserDefaultsConfigStore()) {
        let loadedConfig = (try? configStore.load()) ?? AppConfig.defaultConfig()
        self.configStore = configStore
        self.config = loadedConfig
        self.message = ""
        self.interfaceLanguage = FluentaLanguageStore.selectedLanguage
        self.providerAPIKeys = Dictionary(
            uniqueKeysWithValues: LLMProviderPreset.all.map { preset in
                (preset.id, (try? KeychainStore(service: preset.keychainService).loadAPIKey()) ?? "")
            }
        )
        self.selectedPromptModeID = loadedConfig.defaultModeID
    }

    var selectedProvider: LLMProviderPreset {
        config.resolvedProviderPreset
    }

    var isCustomOpenAICompatibleProvider: Bool {
        config.providerID == LLMProviderPreset.customOpenAICompatible.id
    }

    var selectedPromptModeIndex: Int? {
        config.promptModes.firstIndex { $0.id == selectedPromptModeID }
    }

    var isAccessibilityTrusted: Bool {
        AccessibilityPermissionService().isTrusted
    }

    func isProviderConfigured(_ provider: LLMProviderPreset) -> Bool {
        !(providerAPIKeys[provider.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func selectProvider(_ providerID: String) {
        config.providerID = providerID
        config.model = LLMProviderPreset.preset(id: providerID).defaultModel
    }

    func addPromptMode() {
        let mode = PromptMode(
            id: "custom-\(Int(Date().timeIntervalSince1970))",
            name: "New Mode",
            description: "Custom transformation mode",
            systemPrompt: "",
            shortcut: nil,
            participatesInAuto: false,
            autoRule: .none,
            sortOrder: (config.promptModes.map(\.sortOrder).max() ?? 0) + 1,
            isVisible: true
        )
        config.promptModes.append(mode)
        selectedPromptModeID = mode.id
    }

    func deleteSelectedPromptMode() {
        guard !PromptMode.builtInIDs.contains(selectedPromptModeID) else {
            return
        }
        config.promptModes.removeAll { $0.id == selectedPromptModeID }
        selectedPromptModeID = config.promptModes.first?.id ?? PromptMode.autoID
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
            FluentaLanguageStore.selectedLanguage = interfaceLanguage
            try configStore.save(config)
            for provider in LLMProviderPreset.all {
                let trimmedKey = (providerAPIKeys[provider.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedKey.isEmpty {
                    try KeychainStore(service: provider.keychainService).saveAPIKey(trimmedKey)
                }
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
    static let appConfigDidSave = Notification.Name("FluentaAppConfigDidSave")
}

private extension PromptMode {
    static let builtInIDs: Set<String> = [
        PromptMode.autoID,
        PromptMode.chineseToEnglishID,
        PromptMode.polishEnglishID,
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

    private var isSavedMessage: Bool {
        model.message == L10n.text("settings.saved")
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            detail
        }
        .frame(width: 800, height: 560)
        .background(FluentaTheme.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: FluentaTheme.cornerRadius))
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    NSApp.keyWindow?.close()
                } label: {
                    Circle().fill(Color(red: 1, green: 0.37, blue: 0.34)).frame(width: 12, height: 12)
                }
                .buttonStyle(.plain)
                Circle().fill(Color(red: 1, green: 0.74, blue: 0.18)).frame(width: 12, height: 12)
                Circle().fill(Color(red: 0.16, green: 0.78, blue: 0.25)).frame(width: 12, height: 12)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) { Divider().opacity(0.45) }

            VStack(alignment: .leading, spacing: 2) {
                Text("Fluenta")
                    .font(.system(size: 14, weight: .semibold))
                Text(L10n.text("settings.sidebar.preferences"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
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
                            Spacer()
                        }
                        .font(.system(size: 13, weight: selectedSection == section ? .semibold : .regular))
                        .foregroundStyle(selectedSection == section ? .primary : .secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(
                            selectedSection == section ? FluentaTheme.primary.opacity(0.18) : Color.clear
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 6)

            Spacer()
            Text("Version 1.0.0")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .top) { Divider().opacity(0.45) }
        }
        .frame(width: 200)
        .background(Color(nsColor: .underPageBackgroundColor).opacity(0.75))
        .overlay(alignment: .trailing) { Divider().opacity(0.55) }
    }

    private var detail: some View {
        VStack(spacing: 0) {
            detailHeader
            Divider().opacity(0.55)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    switch selectedSection {
                    case .general:
                        generalPanel
                    case .providers:
                        providersPanel
                    case .promptModes:
                        promptModesPanel
                    case .permissions:
                        permissionsPanel
                    }
                }
                .padding(24)
            }

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
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
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

            settingsRow(L10n.text("settings.row.hotkey"), help: L10n.text("settings.help.hotkey")) {
                HotkeyRecorderField(hotkey: $model.config.hotkey)
                    .frame(width: 220, height: 34)
            }

            settingsRow(L10n.text("settings.row.defaultMode"), help: L10n.text("settings.help.defaultMode")) {
                Picker("", selection: $model.config.defaultModeID) {
                    ForEach(model.config.promptModes) { mode in
                        Text(mode.localizedName).tag(mode.id)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 320, alignment: .leading)
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
        let selectedProviderBinding = Binding(
            get: { model.config.providerID },
            set: { model.selectProvider($0) }
        )
        let selectedAPIKeyBinding = Binding(
            get: { model.providerAPIKeys[model.config.providerID] ?? "" },
            set: { model.providerAPIKeys[model.config.providerID] = $0 }
        )

        return HStack(alignment: .top, spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                ForEach(LLMProviderPreset.all) { provider in
                    Button {
                        model.selectProvider(provider.id)
                    } label: {
                        HStack {
                            Text(provider.name)
                                .font(.system(size: 13, weight: provider.id == model.config.providerID ? .semibold : .regular))
                            Spacer()
                            if model.isProviderConfigured(provider) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(FluentaTheme.success)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            provider.id == model.config.providerID ? FluentaTheme.primary.opacity(0.14) : Color.clear
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            }
            .frame(width: 200)
            .overlay(alignment: .trailing) { Divider().opacity(0.55) }

            VStack(alignment: .leading, spacing: 20) {
                providerStatusHeader
                settingsRow(L10n.text("settings.row.provider"), help: L10n.text("settings.help.provider")) {
                    Picker("", selection: selectedProviderBinding) {
                        ForEach(LLMProviderPreset.all) { provider in
                            Text(provider.name).tag(provider.id)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 320, alignment: .leading)
                }

                settingsRow(L10n.text("settings.row.apiKey"), help: L10n.text("settings.help.apiKey")) {
                    SecureField(model.selectedProvider.apiKeyPlaceholder, text: selectedAPIKeyBinding)
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
                    TextField(model.selectedProvider.defaultModel, text: $model.config.model)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding(24)
        }
    }

    private var providerStatusHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(model.selectedProvider.name)
                    .font(.system(size: 16, weight: .semibold))
                Text(model.isProviderConfigured(model.selectedProvider) ? "Configured" : "Not configured")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if model.isProviderConfigured(model.selectedProvider) {
                Text("Active")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FluentaTheme.success)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(FluentaTheme.success.opacity(0.18), in: RoundedRectangle(cornerRadius: 6))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(FluentaTheme.success.opacity(0.3))
                    }
            }
        }
    }

    private var promptModesPanel: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(model.config.promptModes) { mode in
                            Button {
                                model.selectedPromptModeID = mode.id
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "line.3.horizontal")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.tertiary)
                                    Text(mode.name.isEmpty ? L10n.text("settings.mode.untitled") : mode.localizedName)
                                        .font(.system(size: 13, weight: mode.id == model.selectedPromptModeID ? .semibold : .regular))
                                        .lineLimit(1)
                                    Spacer()
                                    Image(systemName: mode.isVisible ? "eye" : "eye.slash")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(mode.id == model.selectedPromptModeID ? FluentaTheme.primary.opacity(0.14) : Color.clear)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Divider().opacity(0.55)
                Button {
                    model.addPromptMode()
                } label: {
                    Label("Add Mode", systemImage: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .overlay {
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                                .foregroundStyle(FluentaTheme.subtleBorder)
                        }
                }
                .buttonStyle(.plain)
                .padding(12)
            }
            .frame(width: 200)
            .overlay(alignment: .trailing) { Divider().opacity(0.55) }

            if let index = model.selectedPromptModeIndex {
                promptModeDetail(index: index)
            } else {
                Text(L10n.text("settings.mode.pick"))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 280)
            }
        }
    }

    private func promptModeDetail(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(spacing: 14) {
                    settingsRow(L10n.text("settings.row.name"), help: L10n.text("settings.help.name")) {
                        TextField(L10n.text("settings.row.name"), text: $model.config.promptModes[index].name)
                            .textFieldStyle(.roundedBorder)
                    }

                    settingsRow(L10n.text("settings.row.description"), help: L10n.text("settings.help.description")) {
                        TextField(L10n.text("settings.row.description"), text: $model.config.promptModes[index].description)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                if !PromptMode.builtInIDs.contains(model.config.promptModes[index].id) {
                    Button {
                        model.deleteSelectedPromptMode()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.text("settings.row.systemPrompt"))
                    .font(.system(size: 13, weight: .semibold))

                TextEditor(text: $model.config.promptModes[index].systemPrompt)
                    .font(.system(size: 13))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 140)
                    .padding(10)
                    .modifier(FluentaFieldModifier())
            }

            VStack(spacing: 12) {
                settingsToggle(title: "Visible in menu", subtitle: "Show this mode in the mode selector", isOn: $model.config.promptModes[index].isVisible)
                settingsToggle(title: "Auto-match", subtitle: "Include in Auto mode detection", isOn: $model.config.promptModes[index].participatesInAuto)
            }
        }
        .padding(24)
    }

    private var permissionsPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: model.isAccessibilityTrusted ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(model.isAccessibilityTrusted ? FluentaTheme.success : FluentaTheme.warning)
                        .frame(width: 40, height: 40)
                        .background((model.isAccessibilityTrusted ? FluentaTheme.success : FluentaTheme.warning).opacity(0.18), in: RoundedRectangle(cornerRadius: 9))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Accessibility")
                            .font(.system(size: 14, weight: .semibold))
                        Text(L10n.text("settings.permission.description"))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Text(model.isAccessibilityTrusted ? L10n.text("settings.permission.authorized") : L10n.text("settings.permission.required"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(model.isAccessibilityTrusted ? FluentaTheme.success : FluentaTheme.warning)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background((model.isAccessibilityTrusted ? FluentaTheme.success : FluentaTheme.warning).opacity(0.16), in: RoundedRectangle(cornerRadius: 6))
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
            .background(FluentaTheme.elevatedBackground, in: RoundedRectangle(cornerRadius: 9))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .stroke(FluentaTheme.subtleBorder)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Privacy & Security")
                    .font(.system(size: 14, weight: .semibold))
                VStack(alignment: .leading, spacing: 6) {
                    Text("• API keys are stored in macOS Keychain")
                    Text("• Text is sent directly to the selected provider")
                    Text("• Clipboard contents are restored after insertion")
                }
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(FluentaTheme.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .stroke(FluentaTheme.subtleBorder)
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
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.regularMaterial)
    }

    private func settingsPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
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
        VStack(alignment: .leading, spacing: 7) {
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
                    .lineLimit(2)
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
