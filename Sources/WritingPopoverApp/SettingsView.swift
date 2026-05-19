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
        LLMProviderPreset.preset(id: config.providerID)
    }

    var selectedPromptModeIndex: Int? {
        config.promptModes.firstIndex { $0.id == selectedPromptModeID }
    }

    var isAccessibilityTrusted: Bool {
        AccessibilityPermissionService().isTrusted
    }

    func selectProvider(_ providerID: String) {
        config.providerID = providerID
        config.model = LLMProviderPreset.preset(id: providerID).defaultModel
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
            Divider().opacity(0.5)
            detail
        }
        .frame(minWidth: 860, minHeight: 620)
        .background(.regularMaterial)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Fluenta")
                        .font(.headline)
                    Text(L10n.text("settings.sidebar.preferences"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 16)

            VStack(spacing: 4) {
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
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            selectedSection == section ? Color.accentColor.opacity(0.16) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)

            Spacer()
            Text(L10n.text("settings.sidebar.hint"))
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)
                .padding(14)
        }
        .frame(width: 210)
        .background(.ultraThinMaterial)
    }

    private var detail: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    sectionHeader

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
                .padding(26)
            }

            Divider().opacity(0.5)
            footer
        }
    }

    private var sectionHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(selectedSection.title)
                .font(.title2.weight(.semibold))
            Text(sectionDescription)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
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

        return HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 4) {
                ForEach(LLMProviderPreset.all) { provider in
                    Button {
                        model.selectProvider(provider.id)
                    } label: {
                        HStack {
                            Text(provider.name)
                                .font(.system(size: 13, weight: provider.id == model.config.providerID ? .semibold : .regular))
                            Spacer()
                            if provider.id == model.config.providerID {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            provider.id == model.config.providerID ? Color.accentColor.opacity(0.15) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .frame(width: 220)
            .background(FluentaTheme.elevatedBackground, in: RoundedRectangle(cornerRadius: FluentaTheme.controlRadius))
            .overlay {
                RoundedRectangle(cornerRadius: FluentaTheme.controlRadius)
                    .stroke(FluentaTheme.subtleBorder)
            }

            settingsPanel {
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

                settingsRow(L10n.text("settings.row.model"), help: L10n.format("settings.help.model.default", model.selectedProvider.defaultModel)) {
                    TextField(model.selectedProvider.defaultModel, text: $model.config.model)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }

    private var promptModesPanel: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 4) {
                ForEach(model.config.promptModes) { mode in
                    Button {
                        model.selectedPromptModeID = mode.id
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode.name.isEmpty ? L10n.text("settings.mode.untitled") : mode.localizedName)
                                    .font(.system(size: 13, weight: mode.id == model.selectedPromptModeID ? .semibold : .regular))
                                Text(mode.isVisible ? L10n.text("settings.mode.visible") : L10n.text("settings.mode.hidden"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            mode.id == model.selectedPromptModeID ? Color.accentColor.opacity(0.15) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .frame(width: 230)
            .background(FluentaTheme.elevatedBackground, in: RoundedRectangle(cornerRadius: FluentaTheme.controlRadius))
            .overlay {
                RoundedRectangle(cornerRadius: FluentaTheme.controlRadius)
                    .stroke(FluentaTheme.subtleBorder)
            }

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
        settingsPanel {
            HStack {
                Toggle(L10n.text("settings.mode.visible"), isOn: $model.config.promptModes[index].isVisible)
                    .toggleStyle(.switch)
                Toggle("Auto", isOn: $model.config.promptModes[index].participatesInAuto)
                    .toggleStyle(.switch)
                Spacer()
                Text(model.config.promptModes[index].id)
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
            }

            settingsRow(L10n.text("settings.row.name"), help: L10n.text("settings.help.name")) {
                TextField(L10n.text("settings.row.name"), text: $model.config.promptModes[index].name)
                    .textFieldStyle(.roundedBorder)
            }

            settingsRow(L10n.text("settings.row.description"), help: L10n.text("settings.help.description")) {
                TextField(L10n.text("settings.row.description"), text: $model.config.promptModes[index].description)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(L10n.text("settings.row.systemPrompt"), systemImage: "curlybraces")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(L10n.format("settings.characters", model.config.promptModes[index].systemPrompt.count))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                TextEditor(text: $model.config.promptModes[index].systemPrompt)
                    .font(.system(size: 13))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 220)
                    .padding(10)
                    .background(FluentaTheme.fieldBackground, in: RoundedRectangle(cornerRadius: FluentaTheme.controlRadius))
                    .overlay {
                        RoundedRectangle(cornerRadius: FluentaTheme.controlRadius)
                            .stroke(FluentaTheme.subtleBorder)
                    }
            }
        }
    }

    private var permissionsPanel: some View {
        settingsPanel {
            HStack(spacing: 12) {
                Image(systemName: model.isAccessibilityTrusted ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(model.isAccessibilityTrusted ? Color.green : Color.orange)
                    .frame(width: 42, height: 42)
                    .background(.quaternary.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text(model.isAccessibilityTrusted ? L10n.text("settings.permission.authorized") : L10n.text("settings.permission.required"))
                        .font(.headline)
                    Text(L10n.text("settings.permission.description"))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Button {
                model.openAccessibilitySettings()
            } label: {
                Label(L10n.text("settings.permission.open"), systemImage: "arrow.up.forward.app")
            }
            .buttonStyle(.borderedProminent)
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
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FluentaTheme.elevatedBackground, in: RoundedRectangle(cornerRadius: FluentaTheme.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: FluentaTheme.cornerRadius)
                .stroke(FluentaTheme.subtleBorder)
        }
    }

    private func settingsRow<Content: View>(
        _ title: String,
        help: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(title)
                    .foregroundStyle(.primary)
                Text(help)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            }
            .frame(width: 150, alignment: .trailing)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 36)
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
