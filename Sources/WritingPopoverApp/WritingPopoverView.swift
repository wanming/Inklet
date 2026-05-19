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

    var currentProviderName: String {
        LLMProviderPreset.preset(id: config.providerID).name
    }

    var currentModelName: String {
        config.model
    }

    private var stateMachine: PopoverStateMachine
    private let configStore: UserDefaultsConfigStore
    private let keychainStore: KeychainStore
    private let insertionService: InsertionService
    private let transformationServiceFactory: (any LLMProvider) -> TransformationService
    private var config: AppConfig
    private var previousApplication: NSRunningApplication?
    private var transformationTask: Task<Void, Never>?
    private var sessionID = 0

    init(
        stateMachine: PopoverStateMachine = PopoverStateMachine(),
        configStore: UserDefaultsConfigStore = UserDefaultsConfigStore(),
        keychainStore: KeychainStore = KeychainStore(),
        transformationServiceFactory: @escaping (any LLMProvider) -> TransformationService = { TransformationService(provider: $0) },
        insertionService: InsertionService = InsertionService()
    ) {
        self.stateMachine = stateMachine
        self.configStore = configStore
        self.keychainStore = keychainStore
        self.transformationServiceFactory = transformationServiceFactory
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
            errorMessage = L10n.text("popover.error.emptyOriginal")
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
                errorMessage = localizedStateMachineMessage(message)
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
        let providerPreset = config.resolvedProviderPreset
        let provider = LLMProviderFactory.provider(for: providerPreset) {
            try OpenAIAPIKeyProvider(
                keychainStore: KeychainStore(service: providerPreset.keychainService),
                providerName: providerPreset.name
            ).loadAPIKey()
        }
        let transformationService = transformationServiceFactory(provider)

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

    private func localizedStateMachineMessage(_ message: String) -> String {
        switch message {
        case "请输入要转换的文本":
            L10n.text("error.emptySource")
        default:
            message
        }
    }

    private func insert(text: String, fallbackState: PopoverStateMachine.State) {
        guard let previousApplication else {
            stateMachine = PopoverStateMachine(state: fallbackState)
            errorMessage = L10n.text("popover.error.missingTarget")
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
    let providerName: String

    func loadAPIKey() throws -> String {
        guard let apiKey = try keychainStore.loadAPIKey(),
              !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw TransformationError.provider(L10n.format("popover.error.missingAPIKey", providerName))
        }
        return apiKey
    }
}

private extension Error {
    var userFacingMessage: String {
        if let transformationError = self as? TransformationError {
            switch transformationError {
            case .emptySource:
                return L10n.text("error.emptySource")
            case .emptyResponse:
                return L10n.text("error.emptyResponse")
            case .timeout:
                return L10n.text("error.timeout")
            case .provider(let message):
                return localizedProviderMessage(message)
            }
        }

        if let localizedError = self as? LocalizedError,
           let description = localizedError.errorDescription {
            return description
        }

        if let insertionError = self as? InsertionError {
            switch insertionError {
            case .accessibilityPermissionMissing:
                return L10n.text("insertion.error.accessibility")
            case .activationFailed:
                return L10n.text("insertion.error.activation")
            case .cannotCreatePasteEvent:
                return L10n.text("insertion.error.pasteEvent")
            case .clipboardRestoreFailed:
                return L10n.text("insertion.error.clipboardRestore")
            }
        }

        return String(describing: self)
    }

    private func localizedProviderMessage(_ message: String) -> String {
        for providerName in LLMProviderPreset.all.map(\.name) {
            let prefix = "\(providerName) 请求失败："
            guard message.hasPrefix(prefix) else {
                continue
            }

            let detail = String(message.dropFirst(prefix.count))
            if detail == "URL 无效" {
                return L10n.format("error.provider.urlInvalid", providerName)
            }
            if detail == "HTTP unknown" {
                return L10n.format("error.provider.httpUnknown", providerName)
            }
            return L10n.format("error.provider.prefix", providerName, detail)
        }

        return message
    }
}

struct WritingPopoverView: View {
    @ObservedObject var model: WritingPopoverViewModel
    @FocusState private var isSourceFocused: Bool
    @FocusState private var isResultFocused: Bool
    private var isBusy: Bool {
        model.isTransforming || model.isInserting
    }

    private var selectedMode: PromptMode? {
        model.modes.first { $0.id == model.selectedModeID }
    }

    private var primaryActionTitle: String {
        model.resultText.isEmpty ? L10n.text("popover.action.transform") : L10n.text("popover.action.insert")
    }

    private var busyTitle: String {
        model.isInserting ? L10n.text("popover.busy.inserting") : L10n.text("popover.busy.transforming")
    }

    private var modeIconName: String {
        modeIcon(for: model.selectedModeID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().opacity(0.45)
            commandInput
            resultPanel
            statusStrip
            Divider().opacity(0.45)
            actionBar
        }
        .background(
            PopoverKeyEventHandler(
                onSubmit: { model.submit() },
                onInsertOriginal: { model.insertOriginal() },
                onEscape: { model.escape() }
            )
        )
        .frame(width: 580)
        .frame(minHeight: model.resultText.isEmpty ? 232 : 330)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: FluentaTheme.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: FluentaTheme.cornerRadius)
                .stroke(FluentaTheme.strongBorder)
        }
        .shadow(color: .black.opacity(0.5), radius: 28, y: 18)
        .onAppear {
            focusSourceEditor()
        }
        .onChange(of: model.openRevision) {
            focusSourceEditor()
        }
    }

    private var commandInput: some View {
        ZStack(alignment: .bottomTrailing) {
            TextEditor(text: Binding(
                get: { model.sourceText },
                set: { model.updateSourceText($0) }
            ))
            .font(.system(size: 14))
            .lineSpacing(3)
            .scrollContentBackground(.hidden)
            .focused($isSourceFocused)
            .frame(minHeight: model.resultText.isEmpty ? 104 : 92)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            if model.sourceText.isEmpty {
                Text(L10n.text("popover.input.placeholder"))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary.opacity(0.55))
                    .allowsHitTesting(false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 17)
                    .padding(.vertical, 18)
            }

            if isBusy {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text(busyTitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.trailing, 12)
                .padding(.bottom, 10)
            }
        }
    }

    @ViewBuilder
    private var resultPanel: some View {
        if !model.resultText.isEmpty {
            Divider().opacity(0.45)
            ZStack(alignment: .topTrailing) {
                TextEditor(text: Binding(
                    get: { model.resultText },
                    set: { model.updateResultText($0) }
                ))
                .font(.system(size: 14))
                .lineSpacing(3)
                .scrollContentBackground(.hidden)
                .focused($isResultFocused)
                .frame(minHeight: 86)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(FluentaTheme.primary.opacity(0.08))

                Text(L10n.text("popover.result.title"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(FluentaTheme.success)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(FluentaTheme.success.opacity(0.18), in: RoundedRectangle(cornerRadius: 5))
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(FluentaTheme.success.opacity(0.3))
                    }
                    .padding(.top, 10)
                    .padding(.trailing, 12)
            }
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    isResultFocused = true
                }
            }
        }
    }

    @ViewBuilder
    private var statusStrip: some View {
        if let errorMessage = model.errorMessage {
            Divider().opacity(0.45)
            Text(errorMessage)
                .font(.system(size: 12))
                .foregroundStyle(.red)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.1))
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Menu {
                ForEach(model.modes) { mode in
                    Button {
                        model.selectedModeID = mode.id
                    } label: {
                        Label(mode.localizedName, systemImage: modeIcon(for: mode.id))
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: modeIconName)
                        .font(.system(size: 13, weight: .medium))
                    Text(selectedMode?.localizedName ?? L10n.text("popover.mode.picker"))
                        .font(.system(size: 12, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .menuStyle(.borderlessButton)

            Spacer()

            HStack(spacing: 7) {
                Text(model.currentProviderName)
                Text("·")
                    .foregroundStyle(FluentaTheme.subtleBorder)
                Text(model.currentModelName)
                    .font(.system(size: 11, design: .monospaced))
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial.opacity(0.75))
    }

    private var actionBar: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(spacing: 12) {
                shortcutHint(keys: ["↵"], label: primaryActionTitle)
                shortcutHint(keys: ["⌘", "↵"], label: L10n.text("popover.action.insertOriginal"))
                shortcutHint(keys: ["⇧", "↵"], label: L10n.text("popover.hint.newLine"))
            }

            Spacer()

            shortcutHint(keys: ["esc"], label: model.resultText.isEmpty ? L10n.text("popover.hint.close") : L10n.text("popover.hint.back"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial.opacity(0.55))
        .accessibilityLabel(L10n.text("popover.hint.accessibility"))
    }

    private func shortcutHint(keys: [String], label: String) -> some View {
        HStack(spacing: 4) {
            ForEach(keys, id: \.self) { key in
                Keycap(title: key)
            }
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    private func modeIcon(for modeID: String) -> String {
        switch modeID {
        case PromptMode.autoID:
            "sparkles"
        case PromptMode.chineseToEnglishID:
            "globe.asia.australia"
        case PromptMode.polishEnglishID:
            "wand.and.stars"
        default:
            "arrow.right"
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
