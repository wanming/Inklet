import AppKit
import SwiftUI
import InkletCore

enum InkletTextViewAttachmentEvent {
    case attach(NSTextView)
    case detach(NSTextView)
}

struct InkletPopoverView: View {
    @ObservedObject var model: InkletPopoverViewModel
    private let onSourceTextViewAttachment: (InkletTextViewAttachmentEvent) -> Void
    @FocusState private var isSourceFocused: Bool
    @FocusState private var isResultFocused: Bool
    @State private var sourceMeasuredHeight: CGFloat = 0
    @State private var resultMeasuredHeight: CGFloat = 0
    @State private var statusMeasuredHeight: CGFloat = 34
    @State private var actionBarMeasuredHeight: CGFloat = 36

    init(
        model: InkletPopoverViewModel,
        onSourceTextViewAttachment: @escaping (InkletTextViewAttachmentEvent) -> Void = { _ in }
    ) {
        self.model = model
        self.onSourceTextViewAttachment = onSourceTextViewAttachment
    }

    private let minEditorRows: CGFloat = 2
    private let maxSourceEditorRows: CGFloat = 7
    private let maxResultEditorRows: CGFloat = 13
    private let editorLineHeight: CGFloat = 20
    private let editorVerticalPadding: CGFloat = 24
    private let editorEstimatedCharactersPerLine: CGFloat = 72
    private let headerHeight: CGFloat = 46
    private let actionBarHeight: CGFloat = 36
    private let dividerHeight: CGFloat = 1
    private let staleResultBannerHeight: CGFloat = 24
    private var isBusy: Bool {
        model.isBusy
    }

    private var selectedMode: PromptMode? {
        model.modes.first { $0.id == model.selectedModeID }
    }

    private var primaryActionTitle: String {
        if model.isResultStale {
            return L10n.text("popover.action.regenerate")
        }
        return model.resultText.isEmpty
            ? L10n.text("popover.action.transform")
            : L10n.text("popover.action.insert")
    }

    private var busyTitle: String {
        model.isInserting ? L10n.text("popover.busy.inserting") : L10n.text("popover.busy.transforming")
    }

    private var modeIconName: String {
        writingModeIconName(for: model.selectedModeID)
    }

    private var selectedModeDisplayName: String {
        guard let selectedMode else {
            return L10n.text("popover.mode.picker")
        }
        return selectedMode.localizedName
    }

    private var popoverHeight: CGFloat {
        switch model.route {
        case .modePicker:
            WritingModePickerView.preferredHeight(
                resultCount: model.modePickerState.filteredItems.count
            )
        case .editor:
            editorPopoverHeight
        }
    }

    private var editorPopoverHeight: CGFloat {
        headerHeight
            + dividerHeight
            + inputHeight
            + (model.resultText.isEmpty ? 0 : dividerHeight + resultPanelHeight)
            + (model.errorMessage == nil ? 0 : dividerHeight + min(statusMeasuredHeight, 120))
            + dividerHeight
            + max(actionBarHeight, actionBarMeasuredHeight)
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

    private var resultPanelHeight: CGFloat {
        resultHeight + (showsStaleResultBanner ? staleResultBannerHeight : 0)
    }

    private var showsStaleResultBanner: Bool {
        model.isResultStale && model.resultModeDisplayName != nil
    }

    var body: some View {
        Group {
            switch model.route {
            case .modePicker:
                WritingModePickerView(model: model)
            case .editor:
                editorContent
            }
        }
        .background(
            PopoverKeyEventHandler(
                route: model.route,
                onSubmit: { model.submit() },
                onInsertOriginal: { model.insertOriginal() },
                onEscape: { model.escape() },
                onCycleMode: { model.cyclePromptMode(direction: $0) },
                onMoveModeHighlight: { model.moveModeHighlight(by: $0) },
                onCommitMode: { model.commitHighlightedMode() }
            )
        )
        .frame(width: 600, height: popoverHeight, alignment: .top)
        .background(InkletTheme.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(InkletTheme.strongBorder)
        }
        .shadow(color: .black.opacity(0.75), radius: 48, x: 0, y: 28)
        .shadow(color: .white.opacity(0.03), radius: 0, x: 0, y: 1)
        .onAppear {
            publishPopoverHeight()
        }
        .onChange(of: popoverHeight) {
            publishPopoverHeight()
        }
        .onPreferenceChange(ActionBarHeightPreferenceKey.self) { height in
            actionBarMeasuredHeight = height
        }
    }

    private var editorContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().opacity(0.45)
            commandInput
            resultPanel
            statusStrip
            Divider().opacity(0.45)
            actionBar
        }
    }

    private var commandInput: some View {
        ZStack(alignment: .bottomTrailing) {
            InkletTextView(
                text: Binding(
                    get: { model.sourceText },
                    set: { model.updateSourceText($0) }
                ),
                placeholder: L10n.text("popover.input.placeholder"),
                isEditable: !isBusy,
                onSubmit: { model.submit() },
                onInsertOriginal: { model.insertOriginal() },
                onEscape: { model.escape() },
                onTextViewAttachment: onSourceTextViewAttachment
            )
            .accessibilityLabel(L10n.text("dictation.accessibility.sourceEditor"))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
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
            VStack(spacing: 0) {
                if model.isResultStale, let resultModeDisplayName = model.resultModeDisplayName {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 10, weight: .medium))
                        Text(L10n.format("popover.result.generatedWith", resultModeDisplayName))
                            .font(.system(size: 10, weight: .medium))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .foregroundStyle(InkletTheme.textSecondary)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: staleResultBannerHeight)
                    .background(InkletTheme.toolbarBackground)
                    .accessibilityElement(children: .combine)
                }

                ZStack(alignment: .topTrailing) {
                    InkletTextView(
                        text: Binding(
                            get: { model.resultText },
                            set: { model.updateResultText($0) }
                        ),
                        isEditable: !isBusy,
                        onSubmit: { model.submit() },
                        onInsertOriginal: { model.insertOriginal() },
                        onEscape: { model.escape() },
                        onTextViewAttachment: nil
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(InkletTheme.primary.opacity(0.08))
                }
                .frame(height: resultHeight)
                .background {
                    editorHeightReader(for: model.resultText, key: ResultEditorHeightPreferenceKey.self)
                }
                .onPreferenceChange(ResultEditorHeightPreferenceKey.self) { height in
                    resultMeasuredHeight = height
                }
            }
            .frame(height: resultPanelHeight)
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
            ScrollView(.vertical) {
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(.red.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        GeometryReader { proxy in
                            Color.clear.preference(key: StatusHeightPreferenceKey.self, value: proxy.size.height)
                        }
                    }
                    .onPreferenceChange(StatusHeightPreferenceKey.self) { height in
                        statusMeasuredHeight = height
                    }
            }
            .frame(height: min(statusMeasuredHeight, 120))
            .background(Color.red.opacity(0.13))
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 6) {
            Button {
                model.returnToModePicker()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(InkletTheme.textSecondary.opacity(0.78))
                    Image(systemName: modeIconName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(InkletTheme.primary.opacity(0.82))
                    Text(selectedModeDisplayName)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(1)
                }
                .foregroundStyle(InkletTheme.textPrimary.opacity(0.92))
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(Color.clear, in: RoundedRectangle(cornerRadius: 9))
            }
            .buttonStyle(.plain)
            .disabled(isBusy)
            .help(L10n.text("popover.mode.backToModes"))
            .accessibilityLabel(L10n.text("popover.mode.backToModes"))

            Spacer()

            Text("\(model.currentProviderName) · \(model.currentModelName)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(InkletTheme.textSecondary.opacity(0.62))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 188, alignment: .trailing)
                .padding(.trailing, 1)

            Button {
                model.openSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(InkletTheme.textSecondary.opacity(0.72))
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isBusy)
            .help(L10n.text("app.menu.settings"))
            .accessibilityLabel(L10n.text("app.menu.settings"))
        }
        .padding(.horizontal, 14)
        .frame(height: headerHeight)
        .background(Color.white.opacity(0.018))
    }

    private var actionBar: some View {
        Group {
            if model.isTransforming || model.isInserting {
                loadingIndicator
                    .frame(minHeight: max(actionBarHeight, actionBarMeasuredHeight))
            } else {
                WritingActionBarLayout {
                    shortcutHint(keys: ["↵"], label: primaryActionTitle, primary: !model.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !model.resultText.isEmpty) {
                        model.submit()
                    }
                    .disabled(model.dictationPhase.isActive)
                    shortcutHint(keys: ["⌘", "↵"], label: L10n.text("popover.action.insertOriginal")) {
                        model.insertOriginal()
                    }
                    .disabled(model.dictationPhase.isActive)
                    shortcutHint(keys: ["⇧", "↵"], label: L10n.text("popover.hint.newLine")) {
                        insertNewLine()
                    }
                    .disabled(model.dictationPhase.isActive)
                    shortcutHint(keys: ["⌘", "↑/↓"], label: L10n.text("popover.hint.mode")) {
                        model.cyclePromptMode(direction: 1)
                    }
                    .disabled(model.dictationPhase.isActive)
                    HStack(spacing: 3) {
                        if model.shouldShowDictationStatus {
                            dictationStatus
                        }
                        shortcutHint(keys: ["esc"], label: L10n.text("popover.hint.back")) {
                            model.escape()
                        }
                    }
                    .fixedSize()
                }
                .frame(width: 586)
                .padding(.vertical, 8)
            }
        }
        .padding(.horizontal, 7)
        .frame(maxWidth: .infinity, minHeight: actionBarHeight)
        .fixedSize(horizontal: false, vertical: true)
        .background(InkletTheme.toolbarBackground)
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: ActionBarHeightPreferenceKey.self, value: proxy.size.height)
            }
        }
        .accessibilityLabel(L10n.text("popover.hint.accessibility"))
    }

    private var dictationStatus: some View {
        HStack(spacing: 3) {
            Group {
                switch model.dictationPhase {
                case .connecting, .finalizing, .recovering:
                    ProgressView()
                        .controlSize(.mini)
                case .listening:
                    Image(systemName: "waveform")
                case .recordingForFallback:
                    Image(systemName: "mic.badge.plus")
                case .idle, .complete, .failed:
                    Image(systemName: "mic")
                }
            }
            .font(.system(size: 8))
            .frame(width: 16, height: 16)

            Text(model.dictationStatusText)
                .font(.system(size: 8))
                .lineLimit(1)
        }
        .foregroundStyle(InkletTheme.textSecondary.opacity(0.78))
        .fixedSize()
        .padding(.horizontal, 2)
        .help(model.dictationStatusAccessibilityLabel)
        .accessibilityLabel(model.dictationStatusAccessibilityLabel)
    }

    private var loadingIndicator: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(InkletTheme.primary.opacity(0.85))
                        .frame(width: 5, height: 5)
                        .opacity(index == 1 ? 0.65 : 1)
                }
            }
            Text(busyTitle)
                .font(.system(size: 11))
                .foregroundStyle(InkletTheme.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private func shortcutHint(keys: [String], label: String, primary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 2) {
                ForEach(keys, id: \.self) { key in
                    Keycap(title: key, compact: true)
                }
                Text(label)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(primary ? Color.white : InkletTheme.textSecondary)
                    .lineLimit(1)
            }
            .fixedSize()
            .padding(.horizontal, primary ? 5 : 2)
            .padding(.vertical, 2)
            .background(primary ? InkletTheme.primary : Color.white.opacity(0.001), in: RoundedRectangle(cornerRadius: 7))
            .shadow(color: primary ? InkletTheme.primary.opacity(0.35) : .clear, radius: 8, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .fixedSize()
        .contentShape(Rectangle())
        .help(label)
        .accessibilityLabel(label)
    }

    private func insertNewLine() {
        guard !model.isBusy else {
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
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
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

private struct WritingActionBarLayout: Layout {
    private let spacing: CGFloat = 3
    private let rowSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let width = proposal.width ?? sizes.reduce(0) { $0 + $1.width } + spacing * CGFloat(max(0, sizes.count - 1))
        let rows = rows(for: sizes, width: width)
        let height = rows.reduce(CGFloat(0)) { total, row in
            total + row.map { sizes[$0].height }.max()!
        } + rowSpacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var y = bounds.minY
        for row in rows(for: sizes, width: bounds.width) {
            let height = row.map { sizes[$0].height }.max()!
            var x = bounds.minX
            for index in row {
                if index == subviews.count - 1 {
                    x = max(x, bounds.maxX - sizes[index].width)
                }
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (height - sizes[index].height) / 2),
                    proposal: ProposedViewSize(sizes[index])
                )
                x += sizes[index].width + spacing
            }
            y += height + rowSpacing
        }
    }

    private func rows(for sizes: [CGSize], width: CGFloat) -> [[Int]] {
        var rows: [[Int]] = []
        var row: [Int] = []
        var rowWidth: CGFloat = 0
        for index in sizes.indices {
            let nextWidth = rowWidth + (row.isEmpty ? 0 : spacing) + sizes[index].width
            if !row.isEmpty, nextWidth > width {
                rows.append(row)
                row = []
                rowWidth = 0
            }
            rowWidth += (row.isEmpty ? 0 : spacing) + sizes[index].width
            row.append(index)
        }
        if !row.isEmpty { rows.append(row) }
        return rows
    }
}

private struct SourceEditorHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 60

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct StatusHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct ActionBarHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct ResultEditorHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 60

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
