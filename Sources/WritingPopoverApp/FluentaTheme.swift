import AppKit
import SwiftUI
import WritingPopoverCore

extension AppAppearance {
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system:
            nil
        case .light:
            NSAppearance(named: .aqua)
        case .dark:
            NSAppearance(named: .darkAqua)
        }
    }

    var localizedDisplayName: String {
        switch self {
        case .system:
            L10n.text("appearance.system")
        case .light:
            L10n.text("appearance.light")
        case .dark:
            L10n.text("appearance.dark")
        }
    }
}

enum FluentaTheme {
    static let cornerRadius: CGFloat = 12
    static let controlRadius: CGFloat = 8

    static var primary: Color {
        Color(red: 0.28, green: 0.58, blue: 0.94)
    }

    static var success: Color {
        Color(red: 0.26, green: 0.78, blue: 0.45)
    }

    static var warning: Color {
        Color(red: 0.95, green: 0.68, blue: 0.24)
    }

    static var panelBackground: Color {
        Color(nsColor: .windowBackgroundColor)
    }

    static var elevatedBackground: Color {
        Color(nsColor: .controlBackgroundColor).opacity(0.88)
    }

    static var fieldBackground: Color {
        Color(nsColor: .textBackgroundColor).opacity(0.9)
    }

    static var subtleBorder: Color {
        Color.secondary.opacity(0.18)
    }

    static var strongBorder: Color {
        Color.secondary.opacity(0.32)
    }
}

struct Keycap: View {
    var title: String

    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary)
            .frame(minWidth: 20)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(.quaternary.opacity(0.65), in: RoundedRectangle(cornerRadius: 5))
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(FluentaTheme.subtleBorder)
            }
    }
}

struct FluentaFieldModifier: ViewModifier {
    var isFocused = false

    func body(content: Content) -> some View {
        content
            .background(FluentaTheme.fieldBackground, in: RoundedRectangle(cornerRadius: 7))
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(isFocused ? FluentaTheme.primary.opacity(0.75) : FluentaTheme.subtleBorder)
            }
    }
}
