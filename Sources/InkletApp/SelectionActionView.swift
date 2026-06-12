import SwiftUI

enum SelectionActionViewState: Equatable {
    case menu(errorMessage: String?)
    case translating
    case translationResult(String)
    case translationError(String)
}

struct SelectionActionView: View {
    let state: SelectionActionViewState
    let onTranslate: () -> Void
    let onPronounce: () -> Void
    let onCopyTranslation: () -> Void
    let onRetryTranslation: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch state {
            case .menu(let errorMessage):
                HStack(spacing: 8) {
                    compactButton(
                        title: L10n.text("selection.action.translate"),
                        systemImage: "character.bubble",
                        action: onTranslate
                    )
                    compactButton(
                        title: L10n.text("selection.action.pronounce"),
                        systemImage: "speaker.wave.2",
                        action: onPronounce
                    )
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 11))
                        .foregroundStyle(InkletTheme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }

            case .translating:
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(L10n.text("selection.action.translating"))
                        .font(.system(size: 12))
                        .foregroundStyle(InkletTheme.textSecondary)
                }

            case .translationResult(let text):
                VStack(alignment: .leading, spacing: 8) {
                    ScrollView {
                        Text(text)
                            .font(.system(size: 13))
                            .foregroundStyle(InkletTheme.textPrimary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 180)
                    compactButton(
                        title: L10n.text("selection.action.copyTranslation"),
                        systemImage: "doc.on.doc",
                        action: onCopyTranslation
                    )
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
        .padding(12)
        .frame(width: 300, alignment: .leading)
        .background(InkletTheme.panelBackground)
    }

    private func compactButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .frame(minHeight: 26)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}
