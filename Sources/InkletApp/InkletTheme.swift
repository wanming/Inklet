import AppKit
import SwiftUI
import InkletCore

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

enum InkletTheme {
    static let cornerRadius: CGFloat = 12
    static let controlRadius: CGFloat = 8

    static var primary: Color {
        Color(nsColor: .controlAccentColor)
    }

    static var success: Color {
        Color(red: 0.26, green: 0.78, blue: 0.45)
    }

    static var warning: Color {
        Color(red: 0.95, green: 0.68, blue: 0.24)
    }

    static var panelBackground: Color {
        dynamicColor(
            light: NSColor(red: 0.965, green: 0.967, blue: 0.982, alpha: 0.99),
            dark: NSColor(red: 0.047, green: 0.047, blue: 0.078, alpha: 0.985)
        )
    }

    static var elevatedBackground: Color {
        dynamicColor(
            light: NSColor(red: 1, green: 1, blue: 1, alpha: 0.78),
            dark: NSColor(red: 0.078, green: 0.078, blue: 0.133, alpha: 1)
        )
    }

    static var fieldBackground: Color {
        dynamicColor(
            light: NSColor(red: 1, green: 1, blue: 1, alpha: 0.82),
            dark: NSColor(red: 0.078, green: 0.078, blue: 0.133, alpha: 1)
        )
    }

    static var subtleBorder: Color {
        dynamicColor(
            light: NSColor(red: 0, green: 0, blue: 0, alpha: 0.08),
            dark: NSColor(red: 1, green: 1, blue: 1, alpha: 0.07)
        )
    }

    static var strongBorder: Color {
        dynamicColor(
            light: NSColor(red: 0, green: 0, blue: 0, alpha: 0.12),
            dark: NSColor(red: 1, green: 1, blue: 1, alpha: 0.10)
        )
    }

    static var textPrimary: Color {
        dynamicColor(
            light: NSColor(red: 0.105, green: 0.113, blue: 0.145, alpha: 1),
            dark: NSColor(red: 0.933, green: 0.933, blue: 0.949, alpha: 1)
        )
    }

    static var textSecondary: Color {
        dynamicColor(
            light: NSColor(red: 0.365, green: 0.373, blue: 0.463, alpha: 1),
            dark: NSColor(red: 0.471, green: 0.471, blue: 0.627, alpha: 1)
        )
    }

    static var textTertiary: Color {
        dynamicColor(
            light: NSColor(red: 0.530, green: 0.537, blue: 0.620, alpha: 1),
            dark: NSColor(red: 0.353, green: 0.353, blue: 0.447, alpha: 1)
        )
    }

    static var textFaint: Color {
        dynamicColor(
            light: NSColor(red: 0.660, green: 0.670, blue: 0.730, alpha: 1),
            dark: NSColor(red: 0.196, green: 0.196, blue: 0.290, alpha: 1)
        )
    }

    static var glassHighlight: Color {
        dynamicColor(
            light: NSColor(red: 1, green: 1, blue: 1, alpha: 0.78),
            dark: NSColor(red: 1, green: 1, blue: 1, alpha: 0.06)
        )
    }

    static var toolbarBackground: Color {
        dynamicColor(
            light: NSColor(red: 0, green: 0, blue: 0, alpha: 0.025),
            dark: NSColor(red: 1, green: 1, blue: 1, alpha: 0.015)
        )
    }

    static var controlFill: Color {
        dynamicColor(
            light: NSColor(red: 1, green: 1, blue: 1, alpha: 0.72),
            dark: NSColor(red: 1, green: 1, blue: 1, alpha: 0.045)
        )
    }

    private static func dynamicColor(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [.aqua, .darkAqua])
            return match == .darkAqua ? dark : light
        })
    }
}

struct Keycap: View {
    var title: String
    var compact = false

    var body: some View {
        Text(title)
            .font(.system(size: compact ? 8 : 9, weight: .medium, design: .monospaced))
            .foregroundStyle(InkletTheme.textSecondary)
            .frame(minWidth: compact ? 13 : 15, minHeight: compact ? 13 : 15)
            .padding(.horizontal, compact ? 3 : 4)
            .padding(.vertical, compact ? 0 : 1)
            .background(InkletTheme.controlFill, in: RoundedRectangle(cornerRadius: 4))
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(InkletTheme.strongBorder)
            }
    }
}

struct InkletFieldModifier: ViewModifier {
    var isFocused = false

    func body(content: Content) -> some View {
        content
            .background(InkletTheme.fieldBackground, in: RoundedRectangle(cornerRadius: 7))
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(isFocused ? InkletTheme.primary.opacity(0.55) : InkletTheme.subtleBorder)
            }
    }
}

struct InkletTextEditorChromeNormalizer: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            normalizeTextEditors(from: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            normalizeTextEditors(from: nsView)
        }
    }

    private func normalizeTextEditors(from view: NSView) {
        for textView in nearbyTextViews(from: view) {
            textView.textContainerInset = .zero
            textView.textContainer?.lineFragmentPadding = 0
            textView.enclosingScrollView?.contentInsets = NSEdgeInsetsZero
            textView.enclosingScrollView?.automaticallyAdjustsContentInsets = false
            textView.enclosingScrollView?.drawsBackground = false
            textView.enclosingScrollView?.autohidesScrollers = true
            textView.enclosingScrollView?.scrollerStyle = .overlay
            textView.enclosingScrollView?.hasVerticalScroller = false
            textView.enclosingScrollView?.horizontalScrollElasticity = .none
            textView.enclosingScrollView?.hasHorizontalScroller = false
            textView.backgroundColor = .clear
            textView.drawsBackground = false
        }
    }

    private func nearbyTextViews(from view: NSView) -> [NSTextView] {
        var candidate = view.superview
        while let currentView = candidate {
            let textViews = descendantTextViews(in: currentView)
            if !textViews.isEmpty {
                return textViews
            }
            candidate = currentView.superview
        }

        guard let contentView = view.window?.contentView else {
            return []
        }
        return descendantTextViews(in: contentView)
    }

    private func descendantTextViews(in view: NSView) -> [NSTextView] {
        var textViews: [NSTextView] = []
        if let textView = view as? NSTextView {
            textViews.append(textView)
        }

        for subview in view.subviews {
            textViews.append(contentsOf: descendantTextViews(in: subview))
        }

        return textViews
    }
}
