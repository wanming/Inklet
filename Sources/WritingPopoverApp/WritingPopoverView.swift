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

    let modes: [PromptMode]
    var onHidePopover: (() -> Void)?
    var onFocusPopover: (() -> Void)?

    private var stateMachine: PopoverStateMachine
    private let promptModeStore: PromptModeStore
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
        promptModeStore: PromptModeStore = PromptModeStore.defaultStore(),
        configStore: UserDefaultsConfigStore = UserDefaultsConfigStore(),
        keychainStore: KeychainStore = KeychainStore(),
        transformationService: TransformationService? = nil,
        insertionService: InsertionService = InsertionService()
    ) {
        let apiKeyProvider = OpenAIAPIKeyProvider(keychainStore: keychainStore)
        self.stateMachine = stateMachine
        self.promptModeStore = promptModeStore
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
        self.modes = promptModeStore.visibleModes
        self.selectedModeID = loadedConfig.defaultModeID

        if !modes.contains(where: { $0.id == selectedModeID }) {
            self.selectedModeID = modes.first?.id ?? PromptMode.polishEnglishID
        }
    }

    func resetForOpen(previousApplication: NSRunningApplication?) {
        transformationTask?.cancel()
        transformationTask = nil
        sessionID += 1
        self.previousApplication = previousApplication
        stateMachine = PopoverStateMachine()

        config = (try? configStore.load()) ?? AppConfig.defaultConfig()
        sourceText = ""
        resultText = ""
        errorMessage = nil
        isTransforming = false
        isInserting = false
        openRevision += 1

        if !modes.contains(where: { $0.id == selectedModeID }) {
            selectedModeID = config.defaultModeID
        }

        if !modes.contains(where: { $0.id == selectedModeID }) {
            selectedModeID = modes.first?.id ?? PromptMode.polishEnglishID
        }

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

    func submit() {
        guard !isTransforming, !isInserting else {
            return
        }

        errorMessage = nil
        if !resultText.isEmpty {
            let actions = stateMachine.send(.submit)
            if actions.isEmpty {
                insert(text: resultText, fallbackState: .previewingResult(source: sourceText, result: resultText))
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("模式", selection: $model.selectedModeID) {
                ForEach(model.modes) { mode in
                    Text(mode.name).tag(mode.id)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            TextEditor(text: Binding(
                get: { model.sourceText },
                set: { model.updateSourceText($0) }
            ))
                .font(.body)
                .frame(minHeight: 96)
                .focused($isSourceFocused)
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.25))
                }

            HStack(spacing: 10) {
                Button(model.resultText.isEmpty ? "转换" : "插入") {
                    model.submit()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isBusy)

                Button("插入原文") {
                    model.insertOriginal()
                }
                .disabled(isBusy)

                if isBusy {
                    ProgressView()
                        .controlSize(.small)
                }

                Spacer()

                Text("Enter 转换/插入，⌘Enter 插入原文，⇧Enter/⌥Enter 换行，Esc 返回/关闭")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            if !model.resultText.isEmpty {
                TextEditor(text: $model.resultText)
                    .font(.body)
                    .frame(minHeight: 72)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.25))
                    }
            }
        }
        .background(
            PopoverKeyEventHandler(
                onSubmit: { model.submit() },
                onInsertOriginal: { model.insertOriginal() },
                onEscape: { model.escape() }
            )
        )
        .padding(16)
        .frame(minWidth: 520, idealWidth: 520, minHeight: 320)
        .onAppear {
            focusSourceEditor()
        }
        .onChange(of: model.openRevision) {
            focusSourceEditor()
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
