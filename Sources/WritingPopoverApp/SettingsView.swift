import AppKit
import Combine
import SwiftUI
import WritingPopoverCore

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var config: AppConfig
    @Published var message: String
    @Published var providerAPIKeys: [String: String]
    @Published var selectedPromptModeID: String

    private let configStore: UserDefaultsConfigStore

    init(configStore: UserDefaultsConfigStore = UserDefaultsConfigStore()) {
        let loadedConfig = (try? configStore.load()) ?? AppConfig.defaultConfig()
        self.configStore = configStore
        self.config = loadedConfig
        self.message = ""
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
                message = "至少需要保留一个可见模式。"
                return
            }

            guard !config.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                message = "Model 不能为空。"
                return
            }

            _ = try Hotkey.parse(config.hotkey)
            try configStore.save(config)
            for provider in LLMProviderPreset.all {
                let trimmedKey = (providerAPIKeys[provider.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedKey.isEmpty {
                    try KeychainStore(service: provider.keychainService).saveAPIKey(trimmedKey)
                }
            }
            message = "已保存"
            NotificationCenter.default.post(name: .appConfigDidSave, object: nil)
        } catch let error as HotkeyError {
            message = error.localizedDescription
        } catch {
            message = "保存失败：\(String(describing: error))"
        }
    }

    func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else {
            message = "无法打开辅助功能设置。"
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
        model.message == "已保存"
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
                    Text("Preferences")
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
                            Text(section.rawValue)
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
            Text("⌘S 保存 · ⌘, 打开")
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
            Text(selectedSection.rawValue)
                .font(.title2.weight(.semibold))
            Text(sectionDescription)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var sectionDescription: String {
        switch selectedSection {
        case .general:
            "基础行为、快捷键和生成参数。"
        case .providers:
            "选择 LLM 服务商、模型和对应的 API Key。"
        case .promptModes:
            "管理浮窗中的转换模式和系统提示词。"
        case .permissions:
            "检查插入文本所需的 macOS 权限。"
        }
    }

    private var generalPanel: some View {
        settingsPanel {
            settingsRow("Hotkey", help: "例如 ⌥Space、Option+Space、Cmd+Space。") {
                TextField("⌥Space", text: $model.config.hotkey)
                    .textFieldStyle(.roundedBorder)
            }

            settingsRow("Default Mode", help: "浮窗打开时默认选中的模式。") {
                Picker("", selection: $model.config.defaultModeID) {
                    ForEach(model.config.promptModes) { mode in
                        Text(mode.name).tag(mode.id)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 320, alignment: .leading)
            }

            settingsRow("Temperature", help: "低值更稳定，高值更发散。") {
                HStack(spacing: 12) {
                    Slider(value: $model.config.temperature, in: 0...2, step: 0.1)
                    Text(model.config.temperature, format: .number.precision(.fractionLength(1)))
                        .font(.body.monospacedDigit())
                        .frame(width: 42, alignment: .trailing)
                }
            }

            settingsRow("Timeout", help: "请求最长等待时间。") {
                Stepper(value: $model.config.timeoutSeconds, in: 1...120, step: 1) {
                    Text("\(Int(model.config.timeoutSeconds)) 秒")
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
                settingsRow("Provider", help: "当前服务商。") {
                    Picker("", selection: selectedProviderBinding) {
                        ForEach(LLMProviderPreset.all) { provider in
                            Text(provider.name).tag(provider.id)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 320, alignment: .leading)
                }

                settingsRow("API Key", help: "仅保存当前 provider 的 Keychain item。") {
                    SecureField(model.selectedProvider.apiKeyPlaceholder, text: selectedAPIKeyBinding)
                        .textFieldStyle(.roundedBorder)
                }

                settingsRow("Model", help: "默认：\(model.selectedProvider.defaultModel)") {
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
                                Text(mode.name.isEmpty ? "Untitled mode" : mode.name)
                                    .font(.system(size: 13, weight: mode.id == model.selectedPromptModeID ? .semibold : .regular))
                                Text(mode.isVisible ? "Visible" : "Hidden")
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
                Text("选择一个 Prompt Mode")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 280)
            }
        }
    }

    private func promptModeDetail(index: Int) -> some View {
        settingsPanel {
            HStack {
                Toggle("Visible", isOn: $model.config.promptModes[index].isVisible)
                    .toggleStyle(.switch)
                Toggle("Auto", isOn: $model.config.promptModes[index].participatesInAuto)
                    .toggleStyle(.switch)
                Spacer()
                Text(model.config.promptModes[index].id)
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
            }

            settingsRow("Name", help: "浮窗中显示的名称。") {
                TextField("Name", text: $model.config.promptModes[index].name)
                    .textFieldStyle(.roundedBorder)
            }

            settingsRow("Description", help: "模式用途说明。") {
                TextField("Description", text: $model.config.promptModes[index].description)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("System Prompt", systemImage: "curlybraces")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(model.config.promptModes[index].systemPrompt.count) 字符")
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
                    Text(model.isAccessibilityTrusted ? "Accessibility 已授权" : "需要 Accessibility 权限")
                        .font(.headline)
                    Text("Fluenta 需要该权限，才能把生成文本粘贴回当前输入框。")
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Button {
                model.openAccessibilitySettings()
            } label: {
                Label("打开系统权限设置", systemImage: "arrow.up.forward.app")
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
                Text("更改会在保存后应用到下一次浮窗打开。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                model.save()
            } label: {
                Label("保存", systemImage: "checkmark")
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
