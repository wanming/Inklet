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
    @State private var statusMeasuredHeight: CGFloat = 44
    @State private var actionBarMeasuredHeight: CGFloat = InkletTheme.ControlHeight.bar
    @State private var isModeChipHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
    private let editorLineHeight: CGFloat = 21
    private let editorHorizontalPadding = InkletTheme.Spacing.lg
    private let editorVerticalPaddingEdge: CGFloat = 14
    private var editorVerticalPadding: CGFloat { editorVerticalPaddingEdge * 2 }
    private let editorEstimatedCharactersPerLine: CGFloat = 66
    private let headerHeight = InkletTheme.ControlHeight.bar
    private let actionBarHeight = InkletTheme.ControlHeight.bar
    private let dividerHeight: CGFloat = 1
    private let staleResultBannerHeight: CGFloat = 28
    private let resultCardInset = InkletTheme.Spacing.xs
    private let resultTextPadding = InkletTheme.Spacing.sm
    private let resultCopyButtonInset: CGFloat = 32
    private let streamingResultEndID = "streamingResultEnd"
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

    private var isStreamingResult: Bool {
        model.isTransforming && !model.streamingResultText.isEmpty
    }

    /// The streamed partial output while generating, otherwise the editable result.
    private var displayedResultText: String {
        isStreamingResult ? model.streamingResultText : model.resultText
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
            + (displayedResultText.isEmpty ? 0 : resultPanelHeight)
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
            for: displayedResultText,
            measuredHeight: resultMeasuredHeight,
            maxRows: maxResultEditorRows
        )
    }

    /// The result card plus its inset from the panel's bottom edge.
    private var resultPanelHeight: CGFloat {
        resultHeight + (showsStaleResultBanner ? staleResultBannerHeight : 0) + resultCardInset
    }

    private var hasPrimaryActionContent: Bool {
        !model.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !model.resultText.isEmpty
    }

    private var showsStaleResultBanner: Bool {
        !isStreamingResult && model.isResultStale && model.resultModeDisplayName != nil
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
                onCopyResult: { model.copyResult() },
                onEscape: { model.escape() },
                onCycleMode: { model.cyclePromptMode(direction: $0) },
                onMoveModeHighlight: { model.moveModeHighlight(by: $0) },
                onCommitMode: { model.commitHighlightedMode() }
            )
        )
        .frame(width: 600, height: popoverHeight, alignment: .top)
        .inkletFloatingPanel(cornerRadius: InkletTheme.Radius.panel)
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
            hairline
            commandInput
            resultPanel
            statusStrip
            hairline
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
            .padding(.horizontal, editorHorizontalPadding)
            .padding(.vertical, editorVerticalPaddingEdge)
        }
        .frame(height: inputHeight)
        .background {
            editorHeightReader(for: model.sourceText, key: SourceEditorHeightPreferenceKey.self)
        }
        .onPreferenceChange(SourceEditorHeightPreferenceKey.self) { height in
            sourceMeasuredHeight = height
        }
    }

    private var hairline: some View {
        InkletTheme.hairline
            .frame(height: dividerHeight)
    }

    @ViewBuilder
    private var resultPanel: some View {
        if !displayedResultText.isEmpty {
            VStack(spacing: 0) {
                if showsStaleResultBanner, let resultModeDisplayName = model.resultModeDisplayName {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: InkletTheme.IconSize.small, weight: .medium))
                        Text(L10n.format("popover.result.generatedWith", resultModeDisplayName))
                            .font(InkletTheme.Typography.caption)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .foregroundStyle(InkletTheme.secondaryLabel)
                    .padding(.horizontal, resultTextPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: staleResultBannerHeight)
                    .accessibilityElement(children: .combine)
                }

                ZStack(alignment: .topTrailing) {
                    if isStreamingResult {
                        streamingResultView
                    } else {
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
                        .padding(.leading, resultTextPadding)
                        .padding(.trailing, resultTextPadding + resultCopyButtonInset)
                        .padding(.vertical, editorVerticalPaddingEdge)

                        copyResultButton
                    }
                }
                .frame(height: resultHeight)
                .background {
                    editorHeightReader(
                        for: displayedResultText,
                        horizontalPadding: resultTextPadding,
                        trailingInset: resultCopyButtonInset,
                        key: ResultEditorHeightPreferenceKey.self
                    )
                }
                .onPreferenceChange(ResultEditorHeightPreferenceKey.self) { height in
                    resultMeasuredHeight = height
                }
            }
            .inkletCard(
                cornerRadius: InkletTheme.Radius.concentric(outer: InkletTheme.Radius.panel, inset: resultCardInset)
            )
            .padding(.horizontal, resultCardInset)
            .padding(.bottom, resultCardInset)
            .frame(height: resultPanelHeight)
            .transition(InkletTheme.Motion.appear(reduceMotion: reduceMotion))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    isResultFocused = true
                }
            }
        }
    }

    private var streamingResultView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    Text(model.streamingResultText)
                        .font(InkletTheme.Typography.editor)
                        .foregroundStyle(InkletTheme.label)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(.leading, resultTextPadding)
                        .padding(.trailing, resultTextPadding + resultCopyButtonInset)
                        .padding(.vertical, editorVerticalPaddingEdge)
                    Color.clear
                        .frame(height: 0)
                        .id(streamingResultEndID)
                }
            }
            .scrollIndicators(.never)
            .onChange(of: model.streamingResultText) {
                proxy.scrollTo(streamingResultEndID, anchor: .bottom)
            }
        }
    }

    private var copyResultButton: some View {
        Button {
            model.copyResult()
        } label: {
            Image(systemName: model.isResultCopied ? "checkmark" : "doc.on.doc")
                .foregroundStyle(model.isResultCopied ? InkletTheme.statusSuccess : InkletTheme.secondaryLabel)
        }
        .buttonStyle(InkletIconButtonStyle())
        .disabled(isBusy)
        .padding(.top, 6)
        .padding(.trailing, 6)
        .help(L10n.text("popover.action.copyResultHelp"))
        .accessibilityLabel(L10n.text("popover.action.copyResult"))
    }

    @ViewBuilder
    private var statusStrip: some View {
        if let errorMessage = model.errorMessage {
            hairline
            ScrollView(.vertical) {
                InkletStatusBanner(tone: .error, message: errorMessage)
                    .padding(.horizontal, InkletTheme.Spacing.xs)
                    .padding(.vertical, 6)
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
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: InkletTheme.Spacing.xs) {
            Button {
                model.returnToModePicker()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: modeIconName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(InkletTheme.accentText)
                    Text(selectedModeDisplayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(InkletTheme.label)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(InkletTheme.secondaryLabel)
                }
                .padding(.horizontal, 10)
                .frame(height: InkletTheme.ControlHeight.regular)
                .background(
                    isModeChipHovered ? InkletTheme.fillHover : InkletTheme.fill,
                    in: RoundedRectangle(cornerRadius: InkletTheme.Radius.control)
                )
                .contentShape(RoundedRectangle(cornerRadius: InkletTheme.Radius.control))
                .onHover { isModeChipHovered = $0 }
                .animation(InkletTheme.Motion.fast, value: isModeChipHovered)
            }
            .buttonStyle(.plain)
            .disabled(isBusy)
            .help(L10n.text("popover.mode.backToModes"))
            .accessibilityLabel(L10n.text("popover.mode.backToModes"))

            Spacer()

            Text("\(model.currentProviderName) · \(model.currentModelName)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(InkletTheme.tertiaryLabel)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 188, alignment: .trailing)

            Button {
                model.openSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(InkletIconButtonStyle())
            .disabled(isBusy)
            .help(L10n.text("app.menu.settings"))
            .accessibilityLabel(L10n.text("app.menu.settings"))
        }
        .padding(.horizontal, InkletTheme.Spacing.xs)
        .frame(height: headerHeight)
    }

    private var actionBar: some View {
        Group {
            if model.isTransforming || model.isInserting {
                loadingIndicator
                    .frame(minHeight: max(actionBarHeight, actionBarMeasuredHeight))
            } else {
                WritingActionBarLayout {
                    Button {
                        model.submit()
                    } label: {
                        HStack(spacing: 6) {
                            Text(primaryActionTitle)
                            Image(systemName: "return")
                                .font(.system(size: 11, weight: .semibold))
                                .opacity(0.8)
                        }
                    }
                    .buttonStyle(InkletButtonStyle(kind: hasPrimaryActionContent ? .primary : .secondary))
                    .help(primaryActionTitle)
                    .accessibilityLabel(primaryActionTitle)
                    .disabled(model.dictationPhase.isActive)
                    shortcutHint(keys: ["⌘", "↵"], label: L10n.text("popover.action.insertOriginal")) {
                        model.insertOriginal()
                    }
                    .disabled(model.dictationPhase.isActive)
                    shortcutHint(keys: ["⇧", "↵"], label: L10n.text("popover.hint.newLine"), showsLabel: false) {
                        insertNewLine()
                    }
                    .disabled(model.dictationPhase.isActive)
                    shortcutHint(keys: ["⌘", "↑", "↓"], label: L10n.text("popover.hint.mode"), showsLabel: false) {
                        model.cyclePromptMode(direction: 1)
                    }
                    .disabled(model.dictationPhase.isActive)
                    HStack(spacing: InkletTheme.Spacing.xs) {
                        if model.shouldShowDictationStatus {
                            dictationStatus
                        }
                        shortcutHint(keys: ["esc"], label: L10n.text("popover.hint.back")) {
                            model.escape()
                        }
                    }
                    .fixedSize()
                }
                .frame(width: 600 - InkletTheme.Spacing.sm * 2)
                .padding(.vertical, InkletTheme.Spacing.xs)
            }
        }
        .padding(.horizontal, InkletTheme.Spacing.sm)
        .frame(maxWidth: .infinity, minHeight: actionBarHeight)
        .fixedSize(horizontal: false, vertical: true)
        .background(InkletTheme.surfaceSunken)
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: ActionBarHeightPreferenceKey.self, value: proxy.size.height)
            }
        }
        .accessibilityLabel(L10n.text("popover.hint.accessibility"))
    }

    private var dictationStatus: some View {
        HStack(spacing: 4) {
            Group {
                switch model.dictationPhase {
                case .connecting, .finalizing, .recovering:
                    ProgressView()
                        .controlSize(.mini)
                case .listening:
                    Image(systemName: "waveform")
                        .foregroundStyle(InkletTheme.accentText)
                case .recordingForFallback:
                    Image(systemName: "mic.badge.plus")
                case .idle, .complete, .failed:
                    Image(systemName: "mic")
                }
            }
            .font(.system(size: 11, weight: .medium))
            .frame(width: 16, height: 16)

            Text(model.dictationStatusText)
                .font(InkletTheme.Typography.caption)
                .lineLimit(1)
        }
        .foregroundStyle(InkletTheme.secondaryLabel)
        .fixedSize()
        .help(model.dictationStatusAccessibilityLabel)
        .accessibilityLabel(model.dictationStatusAccessibilityLabel)
    }

    private var loadingIndicator: some View {
        HStack(spacing: InkletTheme.Spacing.xs) {
            ProgressView()
                .controlSize(.small)
            Text(busyTitle)
                .font(InkletTheme.Typography.help)
                .foregroundStyle(InkletTheme.secondaryLabel)
            Spacer()
            if model.isTransforming {
                shortcutHint(keys: ["esc"], label: L10n.text("popover.hint.stop")) {
                    model.escape()
                }
            }
        }
        .padding(.leading, 4)
    }

    /// Keycaps with a caption label. Without `showsLabel` it is keycaps only, named by its tooltip.
    private func shortcutHint(
        keys: [String],
        label: String,
        showsLabel: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                ForEach(keys, id: \.self) { key in
                    Keycap(title: key, compact: true)
                }
                if showsLabel {
                    Text(label)
                        .font(InkletTheme.Typography.caption)
                        .foregroundStyle(InkletTheme.secondaryLabel)
                        .lineLimit(1)
                        .padding(.leading, 1)
                }
            }
            .fixedSize()
        }
        .buttonStyle(ShortcutHintButtonStyle())
        .fixedSize()
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
        horizontalPadding: CGFloat? = nil,
        trailingInset: CGFloat = 0,
        key: Key.Type
    ) -> some View where Key.Value == CGFloat {
        let horizontalPadding = horizontalPadding ?? editorHorizontalPadding
        return Text(text.isEmpty ? " \n " : text)
            .font(InkletTheme.Typography.editor)
            .lineSpacing(InkletTheme.Typography.editorLineSpacing)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, horizontalPadding)
            .padding(.trailing, horizontalPadding + trailingInset)
            .padding(.vertical, editorVerticalPaddingEdge)
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

/// Lays out the action bar: the first subview (the primary action) sits at the trailing
/// edge with the last subview (dictation status and escape) just before it; the other
/// hints flow from the leading edge and wrap onto extra rows when space runs out.
private struct WritingActionBarLayout: Layout {
    private let spacing: CGFloat = 4
    private let groupSpacing = InkletTheme.Spacing.sm
    private let rowSpacing: CGFloat = 6

    private struct Arrangement {
        var rows: [[Int]]
        var trailing: [Int]
        var trailingWidth: CGFloat
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let width = proposal.width
            ?? sizes.reduce(0) { $0 + $1.width } + spacing * CGFloat(max(0, sizes.count - 1)) + groupSpacing
        let arrangement = arrangement(for: sizes, width: width)
        let height = rowHeights(for: arrangement, sizes: sizes).reduce(0, +)
            + rowSpacing * CGFloat(max(0, arrangement.rows.count - 1))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let arrangement = arrangement(for: sizes, width: bounds.width)
        let heights = rowHeights(for: arrangement, sizes: sizes)
        var y = bounds.minY
        for (rowIndex, row) in arrangement.rows.enumerated() {
            let height = heights[rowIndex]
            var x = bounds.minX
            for index in row {
                place(subviews[index], size: sizes[index], x: x, y: y, rowHeight: height)
                x += sizes[index].width + spacing
            }
            if rowIndex == 0 {
                var trailingX = bounds.maxX - arrangement.trailingWidth
                for index in arrangement.trailing {
                    place(subviews[index], size: sizes[index], x: trailingX, y: y, rowHeight: height)
                    trailingX += sizes[index].width + spacing
                }
            }
            y += height + rowSpacing
        }
    }

    private func place(_ subview: LayoutSubview, size: CGSize, x: CGFloat, y: CGFloat, rowHeight: CGFloat) {
        subview.place(
            at: CGPoint(x: x, y: y + (rowHeight - size.height) / 2),
            proposal: ProposedViewSize(size)
        )
    }

    private func rowHeights(for arrangement: Arrangement, sizes: [CGSize]) -> [CGFloat] {
        arrangement.rows.enumerated().map { (rowIndex, row) -> CGFloat in
            let indices = rowIndex == 0 ? row + arrangement.trailing : row
            return indices.map { sizes[$0].height }.max() ?? 0
        }
    }

    private func arrangement(for sizes: [CGSize], width: CGFloat) -> Arrangement {
        let trailing = sizes.count > 1 ? [sizes.count - 1, 0] : Array(sizes.indices)
        let trailingWidth = trailing.reduce(CGFloat(0)) { $0 + sizes[$1].width }
            + spacing * CGFloat(max(0, trailing.count - 1))
        var rows: [[Int]] = [[]]
        var rowWidth: CGFloat = 0
        var available = max(0, width - trailingWidth - groupSpacing)
        for index in sizes.indices where !trailing.contains(index) {
            let gap = rows[rows.count - 1].isEmpty ? 0 : spacing
            if !rows[rows.count - 1].isEmpty, rowWidth + gap + sizes[index].width > available {
                rows.append([])
                rowWidth = 0
                available = width
            }
            rowWidth += (rows[rows.count - 1].isEmpty ? 0 : spacing) + sizes[index].width
            rows[rows.count - 1].append(index)
        }
        return Arrangement(rows: rows, trailing: trailing, trailingWidth: trailingWidth)
    }
}

/// Quiet hover feedback for the keycap hints in the action bar.
private struct ShortcutHintButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        ShortcutHintButtonBody(configuration: configuration)
    }
}

private struct ShortcutHintButtonBody: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        configuration.label
            .padding(.horizontal, 4)
            .frame(height: InkletTheme.ControlHeight.small)
            .background(
                configuration.isPressed ? InkletTheme.fillPressed : isHovered ? InkletTheme.fill : .clear,
                in: RoundedRectangle(cornerRadius: InkletTheme.Radius.small)
            )
            .contentShape(RoundedRectangle(cornerRadius: InkletTheme.Radius.small))
            .opacity(isEnabled ? 1 : 0.45)
            .onHover { isHovered = $0 }
            .animation(InkletTheme.Motion.fast, value: isHovered)
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
