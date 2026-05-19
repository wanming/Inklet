import SwiftUI

enum FluentaTheme {
    static let cornerRadius: CGFloat = 14
    static let controlRadius: CGFloat = 10

    static var panelBackground: Color {
        Color(nsColor: .windowBackgroundColor)
    }

    static var elevatedBackground: Color {
        Color(nsColor: .controlBackgroundColor)
    }

    static var fieldBackground: Color {
        Color(nsColor: .textBackgroundColor)
    }

    static var subtleBorder: Color {
        Color.secondary.opacity(0.16)
    }

    static var strongBorder: Color {
        Color.secondary.opacity(0.28)
    }
}

struct Keycap: View {
    var title: String

    var body: some View {
        Text(title)
            .font(.caption.monospaced().weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(FluentaTheme.subtleBorder)
            }
    }
}
