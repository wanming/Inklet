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
    case copiedTranslation
    case loadingOriginalPronunciation
    case playingOriginalPronunciation
    case loadingTranslationPronunciation
    case playingTranslationPronunciation
}

struct SelectionActionView: View {
    let state: SelectionActionViewState
    let onTranslate: () -> Void
    let onPronounce: () -> Void
    let onPronounceOriginal: () -> Void
    let onPronounceTranslation: () -> Void
    let onCopyTranslation: () -> Void
    let onRetryTranslation: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch state {
            case .menu(let errorMessage, let feedback):
                HStack(spacing: 6) {
                    compactButton(
                        title: L10n.text("selection.action.translate"),
                        systemImage: "character.bubble",
                        isLoading: feedback == .loadingMenuTranslation,
                        action: onTranslate
                    )
                    compactButton(
                        title: L10n.text("selection.action.pronounce"),
                        systemImage: feedback == .playingMenuPronunciation ? "speaker.wave.3.fill" : "speaker.wave.2",
                        isLoading: feedback == .loadingMenuPronunciation,
                        action: onPronounce
                    )
                }
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
                    ScrollView {
                        Text(text)
                            .font(.system(size: 13))
                            .foregroundStyle(InkletTheme.textPrimary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 180)
                    HStack(spacing: 6) {
                        compactIconButton(
                            title: L10n.text("selection.action.copyTranslation"),
                            systemImage: feedback == .copiedTranslation ? "checkmark" : "doc.on.doc",
                            action: onCopyTranslation
                        )
                        compactIconButton(
                            title: L10n.text("selection.action.pronounceOriginal"),
                            systemImage: feedback == .playingOriginalPronunciation ? "speaker.wave.3.fill" : "speaker.wave.2",
                            isLoading: feedback == .loadingOriginalPronunciation,
                            action: onPronounceOriginal
                        )
                        compactIconButton(
                            title: L10n.text("selection.action.pronounceTranslation"),
                            systemImage: feedback == .playingTranslationPronunciation ? "speaker.wave.3.fill" : "speaker.wave.2.fill",
                            isLoading: feedback == .loadingTranslationPronunciation,
                            action: onPronounceTranslation
                        )
                    }
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
        .frame(width: preferredWidth, alignment: .leading)
        .background(InkletTheme.panelBackground)
    }

    var preferredWidth: CGFloat {
        switch state {
        case .menu:
            224
        case .preparingPronunciation, .playingPronunciation, .translating:
            210
        default:
            300
        }
    }

    private var panelPadding: EdgeInsets {
        switch state {
        case .menu:
            EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        default:
            EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
        }
    }

    private func compactButton(
        title: String,
        systemImage: String,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                ZStack {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: systemImage)
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
                .frame(width: 15, height: 15)

                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
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
        .disabled(isLoading)
    }

    private func compactIconButton(
        title: String,
        systemImage: String,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .semibold))
                }
            }
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
