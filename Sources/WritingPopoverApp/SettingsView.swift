import AppKit
import Combine
import SwiftUI
import WritingPopoverCore

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var config: AppConfig
    @Published var message: String
    @Published var providerAPIKeys: [String: String]

    private let configStore: UserDefaultsConfigStore

    init(
        configStore: UserDefaultsConfigStore = UserDefaultsConfigStore()
    ) {
        self.configStore = configStore
        self.config = (try? configStore.load()) ?? AppConfig.defaultConfig()
        self.message = ""
        self.providerAPIKeys = Dictionary(
            uniqueKeysWithValues: LLMProviderPreset.all.map { preset in
                (preset.id, (try? KeychainStore(service: preset.keychainService).loadAPIKey()) ?? "")
            }
        )
    }

    var selectedProvider: LLMProviderPreset {
        LLMProviderPreset.preset(id: config.providerID)
    }

    func selectProvider(_ providerID: String) {
        config.providerID = providerID
        let preset = LLMProviderPreset.preset(id: providerID)
        config.model = preset.defaultModel
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
            let provider = selectedProvider
            try KeychainStore(service: provider.keychainService).saveAPIKey(providerAPIKeys[provider.id] ?? "")
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

struct SettingsView: View {
    @StateObject private var model = SettingsViewModel()
    private var isSavedMessage: Bool {
        model.message == "已保存"
    }

    var body: some View {
        let selectedProviderBinding = Binding(
            get: { model.config.providerID },
            set: { model.selectProvider($0) }
        )
        let selectedAPIKeyBinding = Binding(
            get: { model.providerAPIKeys[model.config.providerID] ?? "" },
            set: { model.providerAPIKeys[model.config.providerID] = $0 }
        )

        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    settingsSection(
                        "LLM Provider",
                        systemImage: "sparkles",
                        description: "选择模型服务商并配置对应的 API Key、模型和生成参数。"
                    ) {
                        labeledRow("Provider", help: "支持主流 LLM 服务商。") {
                            Picker("", selection: selectedProviderBinding) {
                                ForEach(LLMProviderPreset.all) { provider in
                                    Text(provider.name).tag(provider.id)
                                }
                            }
                            .labelsHidden()
                            .frame(maxWidth: 320, alignment: .leading)
                        }

                        labeledRow("API Key", help: "保存在系统钥匙串中。") {
                            SecureField(model.selectedProvider.apiKeyPlaceholder, text: selectedAPIKeyBinding)
                                .textFieldStyle(.roundedBorder)
                        }

                        labeledRow("Model", help: "用于转换文本的模型。") {
                            TextField(model.selectedProvider.defaultModel, text: $model.config.model)
                                .textFieldStyle(.roundedBorder)
                        }

                        labeledRow("Temperature", help: "更低更稳定，更高更发散。") {
                            HStack(spacing: 12) {
                                Slider(value: $model.config.temperature, in: 0...2, step: 0.1)
                                Text(model.config.temperature, format: .number.precision(.fractionLength(1)))
                                    .font(.body.monospacedDigit())
                                    .frame(width: 40, alignment: .trailing)
                            }
                        }

                        labeledRow("Timeout", help: "请求最长等待时间。") {
                            Stepper(
                                value: $model.config.timeoutSeconds,
                                in: 1...120,
                                step: 1
                            ) {
                                Text("\(Int(model.config.timeoutSeconds)) 秒")
                                    .font(.body.monospacedDigit())
                            }
                        }
                    }

                    settingsSection(
                        "行为",
                        systemImage: "keyboard",
                        description: "设置唤起快捷键、默认模式和系统权限。"
                    ) {
                        labeledRow("Hotkey", help: "例如 ⌥Space 或 ⌘⇧E。") {
                            TextField("⌥Space", text: $model.config.hotkey)
                                .textFieldStyle(.roundedBorder)
                        }

                        labeledRow("Default Mode", help: "打开浮窗时默认选中的模式。") {
                            Picker("", selection: $model.config.defaultModeID) {
                                ForEach(model.config.promptModes) { mode in
                                    Text(mode.name).tag(mode.id)
                                }
                            }
                            .labelsHidden()
                            .frame(maxWidth: 320, alignment: .leading)
                        }

                        HStack {
                            Spacer()
                            Button {
                                model.openAccessibilitySettings()
                            } label: {
                                Label("打开辅助功能设置", systemImage: "lock.shield")
                            }
                        }
                    }

                    settingsSection(
                        "Prompt Modes",
                        systemImage: "slider.horizontal.3",
                        description: "控制浮窗中的模式名称、可见性、自动匹配和系统提示词。"
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(model.config.promptModes.indices, id: \.self) { index in
                                promptModeEditor(index: index)
                            }
                        }
                    }
                }
                .padding(28)
            }
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

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
        .frame(minWidth: 760, minHeight: 640)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "text.bubble.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text("Fluenta 设置")
                    .font(.title2.weight(.semibold))
                Text("配置模型、快捷键和文本转换模式。")
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private func settingsSection<Content: View>(
        _ title: String,
        systemImage: String,
        description: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 24, height: 24)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.12))
            }
        }
    }

    private func labeledRow<Content: View>(
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
            }
            .frame(width: 150, alignment: .trailing)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 36)
    }

    private func promptModeEditor(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.config.promptModes[index].name.isEmpty ? "Untitled mode" : model.config.promptModes[index].name)
                        .font(.subheadline.weight(.semibold))
                    Text(model.config.promptModes[index].id)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("Visible", isOn: $model.config.promptModes[index].isVisible)
                    .toggleStyle(.switch)
                Toggle("Auto", isOn: $model.config.promptModes[index].participatesInAuto)
                    .toggleStyle(.switch)
            }

            labeledRow("Name", help: "浮窗中显示的名称。") {
                TextField("Name", text: $model.config.promptModes[index].name)
                    .textFieldStyle(.roundedBorder)
            }

            labeledRow("Description", help: "用于说明模式用途。") {
                TextField("Description", text: $model.config.promptModes[index].description)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("System Prompt", systemImage: "curlybraces")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text("\(model.config.promptModes[index].systemPrompt.count) 字符")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                TextEditor(text: $model.config.promptModes[index].systemPrompt)
                    .font(.system(size: 13))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 96)
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.18))
                    }
            }
        }
        .padding(14)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.14))
        }
    }
}
