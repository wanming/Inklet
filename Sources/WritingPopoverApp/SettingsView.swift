import AppKit
import Combine
import SwiftUI
import WritingPopoverCore

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var apiKey: String
    @Published var config: AppConfig
    @Published var message: String

    private let configStore: UserDefaultsConfigStore
    private let keychainStore: KeychainStore

    init(
        configStore: UserDefaultsConfigStore = UserDefaultsConfigStore(),
        keychainStore: KeychainStore = KeychainStore()
    ) {
        self.configStore = configStore
        self.keychainStore = keychainStore
        self.config = (try? configStore.load()) ?? AppConfig.defaultConfig()
        self.apiKey = (try? keychainStore.loadAPIKey()) ?? ""
        self.message = ""
    }

    func save() {
        do {
            try configStore.save(config)
            try keychainStore.saveAPIKey(apiKey)
            message = "已保存"
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

struct SettingsView: View {
    @StateObject private var model = SettingsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    settingsSection("OpenAI") {
                        labeledRow("API Key") {
                            SecureField("sk-...", text: $model.apiKey)
                                .textFieldStyle(.roundedBorder)
                        }

                        labeledRow("Model") {
                            TextField("gpt-4.1-mini", text: $model.config.model)
                                .textFieldStyle(.roundedBorder)
                        }

                        labeledRow("Temperature") {
                            HStack {
                                Slider(value: $model.config.temperature, in: 0...2, step: 0.1)
                                Text(model.config.temperature, format: .number.precision(.fractionLength(1)))
                                    .monospacedDigit()
                                    .frame(width: 36, alignment: .trailing)
                            }
                        }

                        labeledRow("Timeout") {
                            Stepper(
                                value: $model.config.timeoutSeconds,
                                in: 1...120,
                                step: 1
                            ) {
                                Text("\(Int(model.config.timeoutSeconds)) 秒")
                                    .monospacedDigit()
                            }
                        }
                    }

                    settingsSection("行为") {
                        labeledRow("Hotkey") {
                            TextField("⌥Space", text: $model.config.hotkey)
                                .textFieldStyle(.roundedBorder)
                        }

                        labeledRow("Default Mode") {
                            Picker("", selection: $model.config.defaultModeID) {
                                ForEach(model.config.promptModes) { mode in
                                    Text(mode.name).tag(mode.id)
                                }
                            }
                            .labelsHidden()
                            .frame(maxWidth: 280, alignment: .leading)
                        }

                        Button("打开辅助功能设置") {
                            model.openAccessibilitySettings()
                        }
                    }

                    settingsSection("Prompt Modes") {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(model.config.promptModes.indices, id: \.self) { index in
                                promptModeEditor(index: index)
                            }
                        }
                    }
                }
                .padding(24)
            }

            Divider()

            HStack {
                Text(model.message)
                    .foregroundStyle(model.message == "已保存" ? .green : .secondary)
                Spacer()
                Button("保存") {
                    model.save()
                }
                .keyboardShortcut("s", modifiers: .command)
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
        }
        .frame(minWidth: 680, minHeight: 560)
    }

    private func settingsSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func labeledRow<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .frame(width: 120, alignment: .trailing)
                .foregroundStyle(.secondary)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func promptModeEditor(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(model.config.promptModes[index].id)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle("Visible", isOn: $model.config.promptModes[index].isVisible)
                Toggle("Auto", isOn: $model.config.promptModes[index].participatesInAuto)
            }

            labeledRow("Name") {
                TextField("Name", text: $model.config.promptModes[index].name)
                    .textFieldStyle(.roundedBorder)
            }

            labeledRow("Description") {
                TextField("Description", text: $model.config.promptModes[index].description)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("System Prompt")
                    .foregroundStyle(.secondary)
                TextEditor(text: $model.config.promptModes[index].systemPrompt)
                    .font(.body)
                    .frame(minHeight: 88)
                    .padding(4)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(nsColor: .separatorColor))
                    }
            }
        }
        .padding(12)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor))
        }
    }
}
