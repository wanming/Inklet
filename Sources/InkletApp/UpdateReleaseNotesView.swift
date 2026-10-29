import AppKit
import InkletCore
import SwiftUI

/// The release notes inside the update alert: Markdown rendered as headings, bullets and inline
/// styles, in a scroll area that stops growing at `maximumHeight`.
struct UpdateReleaseNotesView: View {
    static let width: CGFloat = 320
    static let maximumHeight: CGFloat = 240

    let blocks: [InkletReleaseNotesBlock]

    static func accessoryView(for notes: String) -> NSView {
        let content = UpdateReleaseNotesView(blocks: InkletReleaseNotes.blocks(notes))
        let contentHeight = NSHostingView(rootView: content.padded).fittingSize.height
        let height = min(contentHeight, maximumHeight)
        let view = NSHostingView(rootView: ScrollView(.vertical) {
            content.padded
        }
        .frame(width: width, height: height)
        .background(InkletTheme.surfaceSunken)
        .clipShape(RoundedRectangle(cornerRadius: InkletTheme.Radius.control)))
        view.frame = NSRect(x: 0, y: 0, width: width, height: height)
        return view
    }

    var body: some View {
        VStack(alignment: .leading, spacing: InkletTheme.Spacing.xs) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                row(block, isFirst: index == 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    private var padded: some View {
        padding(InkletTheme.Spacing.sm)
            .frame(width: Self.width, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func row(_ block: InkletReleaseNotesBlock, isFirst: Bool) -> some View {
        switch block {
        case let .heading(text):
            Text(Self.inline(text))
                .font(InkletTheme.Typography.control)
                .foregroundStyle(InkletTheme.label)
                .padding(.top, isFirst ? 0 : InkletTheme.Spacing.xxs)
                .fixedSize(horizontal: false, vertical: true)
        case let .bullet(text):
            HStack(alignment: .firstTextBaseline, spacing: InkletTheme.Spacing.xs) {
                Text(verbatim: "•")
                    .foregroundStyle(InkletTheme.secondaryLabel)
                Text(Self.inline(text))
                    .foregroundStyle(InkletTheme.label)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(InkletTheme.Typography.body)
        case let .paragraph(text):
            Text(Self.inline(text))
                .font(InkletTheme.Typography.body)
                .foregroundStyle(InkletTheme.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Renders bold, italics, code and links; only https links stay clickable.
    static func inline(_ text: String) -> AttributedString {
        guard let rendered = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) else {
            return AttributedString(text)
        }
        return rendered.transformingAttributes(\.link) { link in
            if link.value?.scheme?.lowercased() != "https" {
                link.value = nil
            }
        }
    }
}
