import Combine
import AppKit
import SwiftUI
import WritingPopoverCore

@MainActor
final class WritingPopoverViewModel: ObservableObject {
    @Published var sourceText = ""
    @Published var resultText = ""
    @Published var errorMessage: String?
    @Published var isTransforming = false
    @Published var isInserting = false
    @Published var selectedModeID: String
    @Published var openRevision = 0
    @Published var modes: [PromptMode]

    var onHidePopover: (() -> Void)?
    var onFocusPopover: (() -> Void)?

    private var stateMachine: PopoverStateMachine
    private let configStore: UserDefaultsConfigStore
    private let keychainStore: KeychainStore
    private let transformationService: TransformationService
    private let insertionService: InsertionService
    private var config: AppConfig
    private var previousApplication: NSRunningApplication?
    private var transformationTask: Task<Void, Never>?
    private var sessionID = 0

    init(
        stateMachine: PopoverStateMachine = PopoverStateMachine(),
        configStore: UserDefaultsConfigStore = UserDefaultsConfigStore(),
        keychainStore: KeychainStore = KeychainStore(),
        transformationService: TransformationService? = nil,
        insertionService: InsertionService = InsertionService()
    ) {
        let apiKeyProvider = OpenAIAPIKeyProvider(keychainStore: keychainStore)
        self.stateMachine = stateMachine
        self.configStore = configStore
        self.keychainStore = keychainStore
        self.transformationService = transformationService ?? TransformationService(
            provider: OpenAIProvider(apiKeyProvider: {
                try apiKeyProvider.loadAPIKey()
            })
        )
        self.insertionService = insertionService

        let loadedConfig = (try? configStore.load()) ?? AppConfig.defaultConfig()
        self.config = loadedConfig
        self.modes = loadedConfig.visiblePromptModes
        self.selectedModeID = loadedConfig.visibleModeID(preferredModeID: loadedConfig.defaultModeID)
    }

    func resetForOpen(previousApplication: NSRunningApplication?) {
        transformationTask?.cancel()
        transformationTask = nil
        sessionID += 1
        self.previousApplication = previousApplication
        stateMachine = PopoverStateMachine()

        config = (try? configStore.load()) ?? AppConfig.defaultConfig()
        modes = config.visiblePromptModes
        selectedModeID = config.visibleModeID(preferredModeID: selectedModeID)
        sourceText = ""
        resultText = ""
        errorMessage = nil
        isTransforming = false
        isInserting = false
        openRevision += 1

        handle(actions: stateMachine.send(.open))
    }

    func updateSourceText(_ text: String) {
        sourceText = text
        guard !isTransforming, !isInserting else {
            return
        }

        if !resultText.isEmpty {
            resultText = ""
        }

        _ = stateMachine.send(.sourceChanged(text))
    }

    func updateResultText(_ text: String) {
        resultText = text
        guard !isTransforming, !isInserting else {
            return
        }

        _ = stateMachine.send(.resultChanged(text))
    }

    func submit() {
        guard !isTransforming, !isInserting else {
            return
        }

        errorMessage = nil
        if !resultText.isEmpty {
            let currentResult = resultText
            _ = stateMachine.send(.resultChanged(currentResult))
            let actions = stateMachine.send(.submit)
            if actions.isEmpty {
                insert(
                    text: currentResult,
                    fallbackState: .previewingResult(source: sourceText, result: currentResult)
                )
            } else {
                handle(actions: actions)
            }
            return
        }

        _ = stateMachine.send(.sourceChanged(sourceText))
        handle(actions: stateMachine.send(.submit))
    }

    func insertOriginal() {
        guard !isTransforming, !isInserting else {
            return
        }

        let trimmedSource = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSource.isEmpty else {
            errorMessage = "请输入要插入的文本。"
            return
        }

        errorMessage = nil
        let fallbackState: PopoverStateMachine.State = resultText.isEmpty
            ? .editingSource(source: sourceText, errorMessage: nil)
            : .previewingResult(source: sourceText, result: resultText)

        if resultText.isEmpty {
            _ = stateMachine.send(.sourceChanged(sourceText))
            let actions = stateMachine.send(.insertOriginal)
            if !actions.isEmpty {
                handle(actions: actions)
                return
            }
        }

        insert(text: sourceText, fallbackState: fallbackState)
    }

    func escape() {
        transformationTask?.cancel()
        transformationTask = nil

        if !resultText.isEmpty {
            resultText = ""
            errorMessage = nil
            handle(actions: stateMachine.send(.escape))
            return
        }

        var actions = stateMachine.send(.escape)
        if actions.isEmpty {
            actions = stateMachine.send(.close)
        }
        handle(actions: actions)
    }

    private func handle(actions: [PopoverStateMachine.Action]) {
        for action in actions {
            switch action {
            case .showPopover:
                onFocusPopover?()
            case .hidePopover:
                onHidePopover?()
            case .focusSourceInput:
                openRevision += 1
            case .startTransformation(let source):
                startTransformation(source: source)
            case .showResult(let result):
                resultText = result
            case .showError(let message):
                errorMessage = message
            case .insertText(let text):
                let fallbackState: PopoverStateMachine.State
                if !resultText.isEmpty {
                    fallbackState = .previewingResult(source: sourceText, result: resultText)
                } else {
                    fallbackState = .editingSource(source: sourceText, errorMessage: nil)
                }
                insert(text: text, fallbackState: fallbackState)
            }
        }
    }

    private func startTransformation(source: String) {
        transformationTask?.cancel()
        resultText = ""
        errorMessage = nil
        isTransforming = true

        selectedModeID = config.visibleModeID(preferredModeID: selectedModeID)
        let promptModeStore = config.promptModeStore
        let mode = promptModeStore.resolve(modeID: selectedModeID, sourceText: source)
        let model = config.model
        let temperature = config.temperature
        let timeoutSeconds = config.timeoutSeconds

        transformationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await transformationService.transform(
                    sourceText: source,
                    mode: mode,
                    model: model,
                    temperature: temperature,
                    timeoutSeconds: timeoutSeconds
                )
                guard !Task.isCancelled else { return }
                isTransforming = false
                handle(actions: stateMachine.send(.transformationSucceeded(result: result.outputText)))
            } catch {
                guard !Task.isCancelled else { return }
                isTransforming = false
                resultText = ""
                handle(actions: stateMachine.send(.transformationFailed(message: error.userFacingMessage)))
            }
        }
    }

    private func insert(text: String, fallbackState: PopoverStateMachine.State) {
        guard let previousApplication else {
            stateMachine = PopoverStateMachine(state: fallbackState)
            errorMessage = "找不到要插入文本的目标应用。"
            return
        }

        isInserting = true
        errorMessage = nil
        onHidePopover?()

        let insertionSessionID = sessionID
        Task { [weak self] in
            guard let self else { return }
            do {
                try await insertionService.insert(text: text, into: previousApplication)
                guard sessionID == insertionSessionID else {
                    return
                }
                isInserting = false
                handle(actions: stateMachine.send(.insertionFinished))
            } catch {
                guard sessionID == insertionSessionID else {
                    return
                }
                isInserting = false
                stateMachine = PopoverStateMachine(state: fallbackState)
                errorMessage = error.userFacingMessage
                onFocusPopover?()
            }
        }
    }
}

private struct OpenAIAPIKeyProvider: @unchecked Sendable {
    let keychainStore: KeychainStore

    func loadAPIKey() throws -> String {
        guard let apiKey = try keychainStore.loadAPIKey(),
              !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw TransformationError.provider("请先配置 OpenAI API Key。")
        }
        return apiKey
    }
}

private extension Error {
    var userFacingMessage: String {
        if let localizedError = self as? LocalizedError,
           let description = localizedError.errorDescription {
            return description
        }

        if let insertionError = self as? InsertionError {
            switch insertionError {
            case .accessibilityPermissionMissing:
                return "需要开启辅助功能权限后才能插入文本。"
            case .activationFailed:
                return "无法切回原应用，请重试。"
            case .cannotCreatePasteEvent:
                return "无法发送粘贴快捷键。"
            case .clipboardRestoreFailed:
                return "插入后恢复剪贴板失败。"
            }
        }

        return String(describing: self)
    }
}

struct WritingPopoverView: View {
    @ObservedObject var model: WritingPopoverViewModel
    @FocusState private var isSourceFocused: Bool
    private var isBusy: Bool {
        model.isTransforming || model.isInserting
    }

    private var selectedMode: PromptMode? {
        model.modes.first { $0.id == model.selectedModeID }
    }

    private var primaryActionTitle: String {
        model.resultText.isEmpty ? "转换" : "插入"
    }

    private var busyTitle: String {
        model.isInserting ? "正在插入..." : "正在转换..."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            modePicker
            editorPanel(
                title: "输入",
                subtitle: selectedMode?.description ?? "输入要转换或插入的文本",
                minHeight: model.resultText.isEmpty ? 132 : 96,
                text: Binding(
                    get: { model.sourceText },
                    set: { model.updateSourceText($0) }
                ),
                isFocused: true
            )

            if !model.resultText.isEmpty {
                editorPanel(
                    title: "结果",
                    subtitle: "可直接编辑后再插入",
                    minHeight: 92,
                    text: Binding(
                        get: { model.resultText },
                        set: { model.updateResultText($0) }
                    ),
                    isFocused: false
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            if let errorMessage = model.errorMessage {
                statusMessage(errorMessage, systemImage: "exclamationmark.triangle.fill", color: .red)
            } else if isBusy {
                statusMessage(busyTitle, systemImage: "sparkles", color: .accentColor)
            }

            actionBar
        }
        .background(
            PopoverKeyEventHandler(
                onSubmit: { model.submit() },
                onInsertOriginal: { model.insertOriginal() },
                onEscape: { model.escape() }
            )
        )
        .padding(18)
        .frame(minWidth: 560, idealWidth: 560, minHeight: 360)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            focusSourceEditor()
        }
        .onChange(of: model.openRevision) {
            focusSourceEditor()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "text.bubble.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text("Fluenta")
                    .font(.system(size: 17, weight: .semibold))
                Text("快速转换、润色并插入文本")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(model.resultText.isEmpty ? "编辑中" : "已生成")
                .font(.caption.weight(.medium))
                .foregroundStyle(model.resultText.isEmpty ? Color.secondary : Color.green)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
        }
    }

    private var modePicker: some View {
        Picker("模式", selection: $model.selectedModeID) {
            ForEach(model.modes) { mode in
                Text(mode.name).tag(mode.id)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .controlSize(.large)
    }

    private var actionBar: some View {
        HStack(alignment: .center, spacing: 10) {
            Button {
                model.submit()
            } label: {
                Label(primaryActionTitle, systemImage: model.resultText.isEmpty ? "wand.and.stars" : "arrow.down.doc.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isBusy)

            Button {
                model.insertOriginal()
            } label: {
                Label("插入原文", systemImage: "text.insert")
            }
            .controlSize(.large)
            .disabled(isBusy)

            if isBusy {
                ProgressView()
                    .controlSize(.small)
                    .padding(.leading, 2)
            }

            Spacer(minLength: 12)

            HStack(spacing: 6) {
                shortcutHint("Enter")
                shortcutHint("⌘Enter")
                shortcutHint("Esc")
            }
            .accessibilityLabel("快捷键：Enter 转换或插入，Command Enter 插入原文，Escape 返回或关闭")
        }
    }

    private func editorPanel(
        title: String,
        subtitle: String,
        minHeight: CGFloat,
        text: Binding<String>,
        isFocused: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
            }

            if isFocused {
                textEditor(text: text, minHeight: minHeight, isActive: isSourceFocused)
                    .focused($isSourceFocused)
            } else {
                textEditor(text: text, minHeight: minHeight, isActive: false)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.12))
        }
    }

    private func textEditor(text: Binding<String>, minHeight: CGFloat, isActive: Bool) -> some View {
        TextEditor(text: text)
            .font(.system(size: 14))
            .scrollContentBackground(.hidden)
            .padding(8)
            .frame(minHeight: minHeight)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isActive ? Color.accentColor.opacity(0.65) : Color.secondary.opacity(0.2), lineWidth: 1)
            }
    }

    private func statusMessage(_ message: String, systemImage: String, color: Color) -> some View {
        Label(message, systemImage: systemImage)
            .font(.footnote)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }

    private func shortcutHint(_ title: String) -> some View {
        Text(title)
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.16))
            }
    }

    private func focusSourceEditor() {
        DispatchQueue.main.async {
            isSourceFocused = true
        }
    }
}

private struct PopoverKeyEventHandler: NSViewRepresentable {
    let onSubmit: () -> Void
    let onInsertOriginal: () -> Void
    let onEscape: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onSubmit = onSubmit
        context.coordinator.onInsertOriginal = onInsertOriginal
        context.coordinator.onEscape = onEscape
        context.coordinator.attach(to: nsView)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.detach()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onSubmit: onSubmit,
            onInsertOriginal: onInsertOriginal,
            onEscape: onEscape
        )
    }

    @MainActor
    final class Coordinator {
        var onSubmit: () -> Void
        var onInsertOriginal: () -> Void
        var onEscape: () -> Void
        private weak var view: NSView?
        private var monitor: Any?

        init(
            onSubmit: @escaping () -> Void,
            onInsertOriginal: @escaping () -> Void,
            onEscape: @escaping () -> Void
        ) {
            self.onSubmit = onSubmit
            self.onInsertOriginal = onInsertOriginal
            self.onEscape = onEscape
        }

        func detach() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        func attach(to view: NSView) {
            self.view = view
            guard monitor == nil else { return }

            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.handle(event) ?? event
            }
        }

        private func handle(_ event: NSEvent) -> NSEvent? {
            guard let window = view?.window,
                  event.window === window,
                  window.isKeyWindow
            else {
                return event
            }

            if event.keyCode == 53 {
                onEscape()
                return nil
            }

            guard event.keyCode == 36 else {
                return event
            }

            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if modifiers.contains(.command) {
                onInsertOriginal()
                return nil
            }

            if !modifiers.contains(.shift), !modifiers.contains(.option) {
                onSubmit()
                return nil
            }

            return event
        }
    }
}
