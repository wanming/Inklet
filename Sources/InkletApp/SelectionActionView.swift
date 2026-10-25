import AppKit
import InkletCore
import SwiftUI

enum SelectionActionViewState: Equatable {
    case menu(errorMessage: String?, feedback: SelectionActionFeedback?)
    case preparingPronunciation
    case playingPronunciation
    case notice(String)
    case translating
    case translationResult(String, errorMessage: String?, feedback: SelectionActionFeedback?)
    case translationError(String)
}

enum SelectionActionFeedback: Equatable {
    case loadingMenuTranslation
    case loadingMenuPronunciation
    case playingMenuPronunciation
    case loadingMenuPromptMode(String)
    case copiedTranslation
    case loadingOriginalPronunciation
    case playingOriginalPronunciation
    case loadingTranslationPronunciation
    case playingTranslationPronunciation
}

struct SelectionActionView: View {
    let state: SelectionActionViewState
    var menuItems: [SelectionMenuItem] = SelectionMenuItem.defaults
    var resultKind: SelectionActionResultKind = .translation
    let onTranslate: () -> Void
    let onPronounce: () -> Void
    let onPronounceOriginal: () -> Void
    let onPronounceTranslation: () -> Void
    let onCopyTranslation: () -> Void
    let onRetryTranslation: () -> Void
    var onRunPromptMode: (String) -> Void = { _ in }
    var onShowMoreActions: ([SelectionMenuItem]) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch state {
            case .menu(let errorMessage, let feedback):
                menuButtonRow(feedback: feedback)
                    .fixedSize(horizontal: true, vertical: false)
                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 11))
                        .foregroundStyle(InkletTheme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }

            case .preparingPronunciation:
                progressRow(title: L10n.text("selection.action.preparingPronunciation"))

            case .playingPronunciation:
                progressRow(title: L10n.text("selection.action.playingPronunciation"))

            case .notice(let message):
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(InkletTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

            case .translating:
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(L10n.text("selection.action.translating"))
                        .font(.system(size: 12))
                        .foregroundStyle(InkletTheme.textSecondary)
                }

            case .translationResult(let text, let errorMessage, let feedback):
                VStack(alignment: .leading, spacing: 8) {
                    translationResultText(text)
                    translationToolbar(feedback: feedback)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 11))
                            .foregroundStyle(InkletTheme.warning)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

            case .translationError(let message):
                VStack(alignment: .leading, spacing: 8) {
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundStyle(InkletTheme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                    compactButton(
                        title: L10n.text("selection.action.retry"),
                        systemImage: "arrow.clockwise",
                        action: onRetryTranslation
                    )
                }
            }
        }
        .padding(panelPadding)
        .frame(
            minWidth: preferredWidth,
            maxWidth: usesFlexiblePanelSize ? .infinity : preferredWidth,
            alignment: .leading
        )
        .frame(maxHeight: usesFlexiblePanelSize ? .infinity : nil, alignment: .topLeading)
        .background(InkletTheme.panelBackground)
    }

    var preferredWidth: CGFloat? {
        switch state {
        case .menu(let errorMessage, _):
            errorMessage == nil ? nil : max(300, estimatedMenuRowWidth + 16)
        case .preparingPronunciation, .playingPronunciation, .translating:
            210
        case .translationResult:
            300
        default:
            300
        }
    }

    /// Matches the chrome in `compactButton` and `moreButton`, so an error message
    /// below a wide menu does not squeeze the buttons.
    private var estimatedMenuRowWidth: CGFloat {
        let layout = SelectionMenuLayout.split(menuItems)
        let buttonWidths = layout.inline.map { item in
            let titleWidth = Self.titleWidth(item.title)
            return (item.promptModeName == nil ? titleWidth : min(titleWidth, Self.promptModeTitleMaxWidth)) + 39
        }
        let moreWidth: CGFloat = layout.overflow.isEmpty ? 0 : 30
        let count = layout.inline.count + (layout.overflow.isEmpty ? 0 : 1)
        return buttonWidths.reduce(0, +) + moreWidth + CGFloat(max(count - 1, 0)) * 6
    }

    private var usesFlexiblePanelSize: Bool {
        if case .translationResult = state {
            return true
        }
        return false
    }

    private var panelPadding: EdgeInsets {
        switch state {
        case .menu:
            EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        default:
            EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
        }
    }

    private var toolbarDisplayStyle: SelectionAudioControlDisplayStyle {
        .flatToolbarAction
    }

    private var toolbarIconSize: CGFloat {
        CGFloat(toolbarDisplayStyle.iconPointSize)
    }

    private var toolbarForegroundColor: Color {
        InkletTheme.textSecondary.opacity(toolbarDisplayStyle.foregroundOpacity)
    }

    private func translationResultText(_ text: String) -> some View {
        ScrollView {
            Text(text)
                .font(.system(size: 13))
                .lineSpacing(2)
                .foregroundStyle(InkletTheme.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
        }
        .frame(maxHeight: usesFlexiblePanelSize ? .infinity : 180)
        .background(InkletTheme.controlFill.opacity(0.58), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(InkletTheme.subtleBorder)
        }
    }

    private func menuButtonRow(feedback: SelectionActionFeedback?) -> some View {
        let layout = SelectionMenuLayout.split(menuItems)
        return HStack(spacing: 6) {
            ForEach(layout.inline) { item in
                compactButton(
                    title: item.title,
                    systemImage: item.systemImage,
                    isLoading: isLoading(item.action, feedback: feedback),
                    isPlaying: item.action == .pronounce && feedback == .playingMenuPronunciation,
                    maxTitleWidth: item.promptModeName == nil ? nil : Self.promptModeTitleMaxWidth,
                    action: { perform(item.action) }
                )
            }
            if !layout.overflow.isEmpty {
                moreButton(
                    items: layout.overflow,
                    isLoading: layout.overflow.contains { isLoading($0.action, feedback: feedback) }
                        || (layout.overflow.contains { $0.action == .pronounce } && feedback == .playingMenuPronunciation)
                )
            }
        }
    }

    private func isLoading(_ action: SelectionMenuAction, feedback: SelectionActionFeedback?) -> Bool {
        switch action {
        case .translate:
            feedback == .loadingMenuTranslation
        case .pronounce:
            feedback == .loadingMenuPronunciation
        case .promptMode(let modeID):
            feedback == .loadingMenuPromptMode(modeID)
        }
    }

    private func perform(_ action: SelectionMenuAction) {
        switch action {
        case .translate:
            onTranslate()
        case .pronounce:
            onPronounce()
        case .promptMode(let modeID):
            onRunPromptMode(modeID)
        }
    }

    private func moreButton(items: [SelectionMenuItem], isLoading: Bool) -> some View {
        let title = L10n.text("selection.action.more")
        return Button {
            onShowMoreActions(items)
        } label: {
            ZStack {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(InkletTheme.textPrimary)
                }
            }
            .frame(width: 15, height: 15)
            .frame(width: 30, height: 30)
            .background(InkletTheme.controlFill, in: RoundedRectangle(cornerRadius: 7))
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(InkletTheme.subtleBorder)
            }
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
        .disabled(isLoading)
    }

    private func translationToolbar(feedback: SelectionActionFeedback?) -> some View {
        HStack(spacing: 4) {
            compactIconButton(
                title: L10n.text(
                    resultKind == .translation ? "selection.action.copyTranslation" : "selection.action.copyResult"
                ),
                systemImage: feedback == .copiedTranslation ? "checkmark" : "doc.on.doc",
                action: onCopyTranslation
            )
            Spacer(minLength: 12)
            compactAudioButton(
                title: L10n.text("selection.action.pronounceOriginal"),
                systemImage: "speaker.wave.2",
                role: .original,
                isLoading: feedback == .loadingOriginalPronunciation,
                isPlaying: feedback == .playingOriginalPronunciation,
                action: onPronounceOriginal
            )
            compactAudioButton(
                title: L10n.text(
                    resultKind == .translation ? "selection.action.pronounceTranslation" : "selection.action.pronounceResult"
                ),
                systemImage: "speaker.wave.2.fill",
                role: .translation,
                labelKey: resultKind == .translation ? nil : "selection.action.audioLabel.result",
                isLoading: feedback == .loadingTranslationPronunciation,
                isPlaying: feedback == .playingTranslationPronunciation,
                action: onPronounceTranslation
            )
        }
        .padding(.top, 6)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(InkletTheme.subtleBorder.opacity(0.55))
                .frame(height: 1)
        }
    }

    private func compactButton(
        title: String,
        systemImage: String,
        isLoading: Bool = false,
        isPlaying: Bool = false,
        maxTitleWidth: CGFloat? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                ZStack {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else if isPlaying {
                        buttonIcon(
                            systemImage: systemImage,
                            fontSize: 12,
                            weight: .semibold,
                            isPlaying: true
                        )
                    } else {
                        buttonIcon(
                            systemImage: systemImage,
                            fontSize: 12,
                            weight: .semibold,
                            isPlaying: false
                        )
                    }
                }
                .frame(width: 15, height: 15)

                if let maxTitleWidth {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(width: min(Self.titleWidth(title), maxTitleWidth), alignment: .leading)
                } else {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .frame(height: 30)
            .padding(.horizontal, 9)
            .background(InkletTheme.controlFill, in: RoundedRectangle(cornerRadius: 7))
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(InkletTheme.subtleBorder)
                }
        }
        .buttonStyle(.plain)
        .help(maxTitleWidth == nil ? "" : title)
        .disabled(isLoading)
    }

    private static let promptModeTitleMaxWidth: CGFloat = 120

    private static func titleWidth(_ title: String) -> CGFloat {
        let font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        return ceil((title as NSString).size(withAttributes: [.font: font]).width)
    }

    private func compactIconButton(
        title: String,
        systemImage: String,
        isLoading: Bool = false,
        isPlaying: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else if isPlaying {
                    buttonIcon(
                        systemImage: systemImage,
                        fontSize: toolbarIconSize,
                        weight: .medium,
                        isPlaying: true,
                        color: toolbarForegroundColor
                    )
                } else {
                    buttonIcon(
                        systemImage: systemImage,
                        fontSize: toolbarIconSize,
                        weight: .medium,
                        isPlaying: false,
                        color: toolbarForegroundColor
                    )
                }
            }
            .frame(width: 14, height: 14)
            .frame(width: 30, height: 30)
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(FlatToolbarButtonStyle())
        .help(title)
        .accessibilityLabel(title)
        .disabled(isLoading)
    }

    private func compactAudioButton(
        title: String,
        systemImage: String,
        role: SelectionAudioControlRole,
        labelKey: String? = nil,
        isLoading: Bool = false,
        isPlaying: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                ZStack {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        buttonIcon(
                            systemImage: systemImage,
                            fontSize: toolbarIconSize,
                            weight: .medium,
                            isPlaying: isPlaying,
                            color: toolbarForegroundColor
                        )
                    }
                }
                .frame(width: 14, height: 14)

                Text(L10n.text(labelKey ?? role.labelLocalizationKey))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(toolbarForegroundColor)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .frame(height: 30)
            .padding(.horizontal, 7)
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(FlatToolbarButtonStyle())
        .help(title)
        .accessibilityLabel(title)
        .disabled(isLoading)
    }

    @ViewBuilder
    private func buttonIcon(
        systemImage: String,
        fontSize: CGFloat,
        weight: Font.Weight,
        isPlaying: Bool,
        color: Color = InkletTheme.textPrimary
    ) -> some View {
        if systemImage.hasPrefix("speaker.wave") {
            SpeakerWaveIcon(
                state: isPlaying ? .playing : .idle,
                fontSize: fontSize,
                weight: weight,
                isFilled: systemImage.hasSuffix(".fill"),
                foregroundColor: color
            )
        } else {
            Image(systemName: systemImage)
                .font(.system(size: fontSize, weight: weight))
                .foregroundStyle(color)
        }
    }

    private func progressRow(title: String) -> some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(InkletTheme.textSecondary)
                .lineLimit(1)
        }
        .frame(minHeight: 28)
    }
}

private struct FlatToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed
                    ? InkletTheme.controlFill.opacity(0.46)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 6)
            )
    }
}
