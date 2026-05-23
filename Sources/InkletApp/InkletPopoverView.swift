import Combine
import AppKit
import SwiftUI
import InkletCore

@MainActor
final class InkletPopoverViewModel: ObservableObject {
    @Published var sourceText = ""
    @Published var resultText = ""
    @Published var errorMessage: String?
    @Published var isTransforming = false
    @Published var isInserting = false
    @Published var selectedModeID: String
    @Published var openRevision = 0
    @Published var modes: [PromptMode]
    @Published var preferredPopoverHeight: CGFloat = 168
    @Published var appearance: AppAppearance

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
    private let apiKeyStore: LocalAPIKeyStore
    private let insertionService: InsertionService
    private let transformationServiceFactory: (any LLMProvider) -> TransformationService
    private var config: AppConfig
    private var previousApplication: NSRunningApplication?
    private var transformationTask: Task<Void, Never>?
    private var sessionID = 0

    init(
        stateMachine: PopoverStateMachine = PopoverStateMachine(),
        configStore: UserDefaultsConfigStore = UserDefaultsConfigStore(),
        apiKeyStore: LocalAPIKeyStore = LocalAPIKeyStore(),
        transformationServiceFactory: @escaping (any LLMProvider) -> TransformationService = { TransformationService(provider: $0) },
        insertionService: InsertionService = InsertionService()
    ) {
        self.stateMachine = stateMachine
        self.configStore = configStore
        self.apiKeyStore = apiKeyStore
        self.transformationServiceFactory = transformationServiceFactory
        self.insertionService = insertionService

        let loadedConfig = (try? configStore.load()) ?? AppConfig.defaultConfig()
        self.config = loadedConfig
        self.modes = loadedConfig.visiblePromptModes
        self.selectedModeID = loadedConfig.defaultVisibleModeID
        self.appearance = loadedConfig.appearance
    }

    func resetForOpen(previousApplication: NSRunningApplication?) {
        transformationTask?.cancel()
        transformationTask = nil
        sessionID += 1
        self.previousApplication = previousApplication
        stateMachine = PopoverStateMachine()

        config = (try? configStore.load()) ?? AppConfig.defaultConfig()
        modes = config.visiblePromptModes
        selectedModeID = config.defaultVisibleModeID
        appearance = config.appearance
        sourceText = ""
        resultText = ""
        errorMessage = nil
        isTransforming = false
        isInserting = false
        preferredPopoverHeight = 168
        openRevision += 1

        handle(actions: stateMachine.send(.open))
    }

    func updateSourceText(_ text: String) {
        guard !isTransforming, !isInserting else {
            return
        }

        sourceText = text
        if !resultText.isEmpty {
            resultText = ""
        }

        _ = stateMachine.send(.sourceChanged(text))
    }

    func updateResultText(_ text: String) {
        guard !isTransforming, !isInserting else {
            return
        }

        resultText = text
        _ = stateMachine.send(.resultChanged(text))
    }

    func cyclePromptMode(direction: Int) {
        guard !modes.isEmpty else {
            return
        }

        let currentIndex = modes.firstIndex { $0.id == selectedModeID } ?? 0
        let nextIndex = (currentIndex + direction + modes.count) % modes.count
        selectedModeID = modes[nextIndex].id
    }

    func submit() {
        guard !isTransforming, !isInserting else {
            return
        }

        errorMessage = nil
        if !resultText.isEmpty {
            removeSingleTrailingNewlineFromResult()
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

        removeSingleTrailingNewlineFromSource()
        _ = stateMachine.send(.sourceChanged(sourceText))
        handle(actions: stateMachine.send(.submit))
    }

    private func removeSingleTrailingNewlineFromSource() {
        if sourceText.hasSuffix("\r\n") {
            sourceText.removeLast(2)
        } else if sourceText.hasSuffix("\n") || sourceText.hasSuffix("\r") {
            sourceText.removeLast()
        }
    }

    private func removeSingleTrailingNewlineFromResult() {
        if resultText.hasSuffix("\r\n") {
            resultText.removeLast(2)
        } else if resultText.hasSuffix("\n") || resultText.hasSuffix("\r") {
            resultText.removeLast()
        }
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
        let providerID = config.providerID
        let apiKeyStore = self.apiKeyStore
        let provider = LLMProviderFactory.provider(for: providerPreset) {
            try LocalAPIKeyProvider(
                apiKeyStore: apiKeyStore,
                providerID: providerID,
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

        errorMessage = nil
        onHidePopover?()
        isInserting = true

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

private struct LocalAPIKeyProvider: @unchecked Sendable {
    let apiKeyStore: LocalAPIKeyStore
    let providerID: String
    let providerName: String

    func loadAPIKey() throws -> String {
        guard let apiKey = apiKeyStore.loadAPIKey(forProviderID: providerID),
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

struct InkletPopoverView: View {
    @ObservedObject var model: InkletPopoverViewModel
    @FocusState private var isSourceFocused: Bool
    @FocusState private var isResultFocused: Bool
    @State private var sourceMeasuredHeight: CGFloat = 0
    @State private var resultMeasuredHeight: CGFloat = 0
    @State private var editorHasMarkedText = false

    private let minEditorRows: CGFloat = 2
    private let maxSourceEditorRows: CGFloat = 7
    private let maxResultEditorRows: CGFloat = 13
    private let editorLineHeight: CGFloat = 20
    private let editorVerticalPadding: CGFloat = 20
    private let editorEstimatedCharactersPerLine: CGFloat = 72
    private let headerHeight: CGFloat = 44
    private let actionBarHeight: CGFloat = 44
    private let dividerHeight: CGFloat = 1
    private let statusHeight: CGFloat = 34
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

    private var popoverHeight: CGFloat {
        headerHeight
            + dividerHeight
            + inputHeight
            + (model.resultText.isEmpty ? 0 : dividerHeight + resultHeight)
            + (model.errorMessage == nil ? 0 : dividerHeight + statusHeight)
            + dividerHeight
            + actionBarHeight
    }

    private var inputHeight: CGFloat {
        editorHeight(
            for: model.sourceText,
            measuredHeight: sourceMeasuredHeight,
            maxRows: maxSourceEditorRows
        )
    }

    private var resultHeight: CGFloat {
        editorHeight(
            for: model.resultText,
            measuredHeight: resultMeasuredHeight,
            maxRows: maxResultEditorRows
        )
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
                onEscape: { model.escape() },
                onCycleMode: { model.cyclePromptMode(direction: $0) }
            )
        )
        .frame(width: 580, height: popoverHeight, alignment: .top)
        .background(InkletTheme.panelBackground.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: InkletTheme.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: InkletTheme.cornerRadius)
                .stroke(InkletTheme.strongBorder)
        }
        .preferredColorScheme(model.appearance.colorScheme)
        .onAppear {
            publishPopoverHeight()
            focusSourceEditor()
        }
        .onChange(of: popoverHeight) {
            publishPopoverHeight()
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
            .background(TextEditorInsetNormalizer(onMarkedTextChange: { editorHasMarkedText = $0 }))
            .focused($isSourceFocused)
            .disabled(isBusy)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            if model.sourceText.isEmpty && !editorHasMarkedText {
                Text(L10n.text("popover.input.placeholder"))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary.opacity(0.55))
                    .allowsHitTesting(false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.leading, 12)
                    .padding(.trailing, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 10)
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
        .frame(height: inputHeight)
        .background {
            editorHeightReader(for: model.sourceText, key: SourceEditorHeightPreferenceKey.self)
        }
        .onPreferenceChange(SourceEditorHeightPreferenceKey.self) { height in
            sourceMeasuredHeight = height
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
                .background(TextEditorInsetNormalizer())
                .focused($isResultFocused)
                .disabled(isBusy)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(InkletTheme.primary.opacity(0.08))
            }
            .frame(height: resultHeight)
            .background {
                editorHeightReader(for: model.resultText, key: ResultEditorHeightPreferenceKey.self)
            }
            .onPreferenceChange(ResultEditorHeightPreferenceKey.self) { height in
                resultMeasuredHeight = height
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
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 170, alignment: .leading)
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
                    .foregroundStyle(InkletTheme.subtleBorder)
                Text(model.currentModelName)
                    .font(.system(size: 11, design: .monospaced))
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(maxWidth: 250, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .frame(height: headerHeight)
        .background(.regularMaterial.opacity(0.75))
    }

    private var actionBar: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(spacing: 12) {
                shortcutHint(keys: ["↵"], label: primaryActionTitle) {
                    model.submit()
                }
                shortcutHint(keys: ["⌘", "↵"], label: L10n.text("popover.action.insertOriginal")) {
                    model.insertOriginal()
                }
                shortcutHint(keys: ["⇧", "↵"], label: L10n.text("popover.hint.newLine")) {
                    insertNewLine()
                }
                shortcutHint(keys: ["⌘", "↑/↓"], label: L10n.text("popover.hint.mode")) {
                    model.cyclePromptMode(direction: 1)
                }
            }

            Spacer()

            shortcutHint(keys: ["esc"], label: model.resultText.isEmpty ? L10n.text("popover.hint.close") : L10n.text("popover.hint.back")) {
                model.escape()
            }
        }
        .padding(.horizontal, 12)
        .frame(height: actionBarHeight)
        .background(.regularMaterial.opacity(0.55))
        .accessibilityLabel(L10n.text("popover.hint.accessibility"))
    }

    private func shortcutHint(keys: [String], label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                ForEach(keys, id: \.self) { key in
                    Keycap(title: key)
                }
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .help(label)
    }

    private func insertNewLine() {
        guard !model.isTransforming, !model.isInserting else {
            return
        }

        if isResultFocused || !model.resultText.isEmpty && !isSourceFocused {
            model.updateResultText(model.resultText + "\n")
            isResultFocused = true
        } else {
            model.updateSourceText(model.sourceText + "\n")
            isSourceFocused = true
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

    private func editorHeight(for text: String, measuredHeight: CGFloat, maxRows: CGFloat) -> CGFloat {
        max(
            clampedEditorHeight(measuredHeight, maxRows: maxRows),
            estimatedEditorHeight(for: text, maxRows: maxRows)
        )
    }

    private func clampedEditorHeight(_ measuredHeight: CGFloat, maxRows: CGFloat) -> CGFloat {
        let minHeight = minEditorRows * editorLineHeight + editorVerticalPadding
        let maxHeight = maxRows * editorLineHeight + editorVerticalPadding
        return min(max(measuredHeight, minHeight), maxHeight)
    }

    private func estimatedEditorHeight(for text: String, maxRows: CGFloat) -> CGFloat {
        let minHeight = minEditorRows * editorLineHeight + editorVerticalPadding
        let maxHeight = maxRows * editorLineHeight + editorVerticalPadding
        guard !text.isEmpty else {
            return minHeight
        }

        let rows = text
            .components(separatedBy: .newlines)
            .map { line -> CGFloat in
                let characterCount = max(line.count, 1)
                return max(ceil(CGFloat(characterCount) / editorEstimatedCharactersPerLine), 1)
            }
            .reduce(CGFloat(0), +)

        return min(max(rows * editorLineHeight + editorVerticalPadding, minHeight), maxHeight)
    }

    private func publishPopoverHeight() {
        guard model.preferredPopoverHeight != popoverHeight else {
            return
        }
        model.preferredPopoverHeight = popoverHeight
    }

    private func editorHeightReader<Key: PreferenceKey>(
        for text: String,
        key: Key.Type
    ) -> some View where Key.Value == CGFloat {
        Text(text.isEmpty ? " \n " : text)
            .font(.system(size: 14))
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .hidden()
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: key,
                        value: proxy.size.height
                    )
                }
            }
    }
}

private struct SourceEditorHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 60

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ResultEditorHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 60

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct TextEditorInsetNormalizer: NSViewRepresentable {
    var onMarkedTextChange: ((Bool) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onMarkedTextChange: onMarkedTextChange)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            normalizeTextEditors(from: view, coordinator: context.coordinator)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onMarkedTextChange = onMarkedTextChange
        DispatchQueue.main.async {
            normalizeTextEditors(from: nsView, coordinator: context.coordinator)
        }
    }

    private func normalizeTextEditors(from view: NSView, coordinator: Coordinator) {
        guard let rootView = view.window?.contentView else {
            return
        }

        let textViews = rootView.descendantTextViews
        for textView in rootView.descendantTextViews {
            textView.textContainerInset = .zero
            textView.textContainer?.lineFragmentPadding = 0
            textView.enclosingScrollView?.contentInsets = NSEdgeInsetsZero
            textView.enclosingScrollView?.automaticallyAdjustsContentInsets = false
            textView.enclosingScrollView?.drawsBackground = false
            textView.enclosingScrollView?.autohidesScrollers = true
            textView.enclosingScrollView?.scrollerStyle = .overlay
            textView.enclosingScrollView?.verticalScroller?.controlSize = .mini
            textView.enclosingScrollView?.verticalScroller?.alphaValue = 0.0
            textView.enclosingScrollView?.horizontalScrollElasticity = .none
            textView.enclosingScrollView?.hasHorizontalScroller = false
            textView.backgroundColor = .clear
            textView.drawsBackground = false
        }
        coordinator.watch(textViews)
    }

    final class Coordinator: NSObject, @unchecked Sendable {
        var onMarkedTextChange: ((Bool) -> Void)?
        private var observedTextViewIDs: Set<ObjectIdentifier> = []
        private var eventMonitor: Any?
        private var textViews: [WeakTextView] = []
        private var lastMarkedTextState = false

        init(onMarkedTextChange: ((Bool) -> Void)?) {
            self.onMarkedTextChange = onMarkedTextChange
            super.init()
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
            if let eventMonitor {
                NSEvent.removeMonitor(eventMonitor)
            }
        }

        @MainActor
        func watch(_ textViews: [NSTextView]) {
            guard onMarkedTextChange != nil else {
                return
            }

            self.textViews = textViews.map(WeakTextView.init)
            installEventMonitorIfNeeded()

            for textView in textViews {
                let id = ObjectIdentifier(textView)
                guard !observedTextViewIDs.contains(id) else {
                    continue
                }
                observedTextViewIDs.insert(id)

                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(textViewStateDidChange),
                    name: NSText.didChangeNotification,
                    object: textView,
                )
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(textViewStateDidChange),
                    name: NSTextView.didChangeSelectionNotification,
                    object: textView,
                )
            }

            publishMarkedTextState()
        }

        @MainActor
        private func installEventMonitorIfNeeded() {
            guard eventMonitor == nil else {
                return
            }

            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
                DispatchQueue.main.async {
                    self?.publishMarkedTextState()
                }
                return event
            } as AnyObject
        }

        @objc @MainActor private func textViewStateDidChange() {
            publishMarkedTextState()
        }

        @MainActor
        private func publishMarkedTextState() {
            let hasMarkedText = textViews.contains { textView in
                textView.value?.hasMarkedText() == true
            }
            guard hasMarkedText != lastMarkedTextState else {
                return
            }

            lastMarkedTextState = hasMarkedText
            onMarkedTextChange?(hasMarkedText)
        }
    }

    private struct WeakTextView {
        weak var value: NSTextView?
    }
}

private extension NSView {
    var descendantTextViews: [NSTextView] {
        var textViews: [NSTextView] = []
        if let textView = self as? NSTextView {
            textViews.append(textView)
        }

        for subview in subviews {
            textViews.append(contentsOf: subview.descendantTextViews)
        }

        return textViews
    }
}

private struct PopoverKeyEventHandler: NSViewRepresentable {
    let onSubmit: () -> Void
    let onInsertOriginal: () -> Void
    let onEscape: () -> Void
    let onCycleMode: (Int) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onSubmit = onSubmit
        context.coordinator.onInsertOriginal = onInsertOriginal
        context.coordinator.onEscape = onEscape
        context.coordinator.onCycleMode = onCycleMode
        context.coordinator.attach(to: nsView)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.detach()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onSubmit: onSubmit,
            onInsertOriginal: onInsertOriginal,
            onEscape: onEscape,
            onCycleMode: onCycleMode
        )
    }

    @MainActor
    final class Coordinator {
        var onSubmit: () -> Void
        var onInsertOriginal: () -> Void
        var onEscape: () -> Void
        var onCycleMode: (Int) -> Void
        private weak var view: NSView?
        private var monitor: Any?

        init(
            onSubmit: @escaping () -> Void,
            onInsertOriginal: @escaping () -> Void,
            onEscape: @escaping () -> Void,
            onCycleMode: @escaping (Int) -> Void
        ) {
            self.onSubmit = onSubmit
            self.onInsertOriginal = onInsertOriginal
            self.onEscape = onEscape
            self.onCycleMode = onCycleMode
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

            let isReturnKey = event.keyCode == 36 || event.keyCode == 76
            if isComposingText, isReturnKey || event.keyCode == 53 {
                return event
            }

            if event.keyCode == 53 {
                onEscape()
                return nil
            }

            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if modifiers.contains(.command), !modifiers.contains(.shift), !modifiers.contains(.option) {
                if event.keyCode == 126 {
                    onCycleMode(-1)
                    return nil
                }

                if event.keyCode == 125 {
                    onCycleMode(1)
                    return nil
                }
            }

            guard isReturnKey else {
                return event
            }

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

        private var isComposingText: Bool {
            guard let responder = view?.window?.firstResponder as? NSTextInputClient else {
                return false
            }

            return responder.hasMarkedText()
        }
    }
}
