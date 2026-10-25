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

// Earlier token names, kept so surfaces that still use them pick up the
// "Ink & Paper" palette. New UI uses the names in InkletDesignTokens.swift
// (docs/DESIGN.md, "Migration from the earlier style").
enum InkletTheme {
    static let cornerRadius: CGFloat = 12
    static let controlRadius: CGFloat = 8

    static var primary: Color {
        Color(nsColor: .controlAccentColor)
    }

    static var success: Color { statusSuccess }
    static var warning: Color { statusWarning }
    static var panelBackground: Color { surface }
    static var elevatedBackground: Color { surfaceRaised }
    static var fieldBackground: Color { surfaceRaised }
    static var subtleBorder: Color { hairline }
    static var strongBorder: Color { strokeStrong }
    static var textPrimary: Color { label }
    static var textSecondary: Color { secondaryLabel }
    static var textTertiary: Color { tertiaryLabel }
    static var textFaint: Color { tertiaryLabel }
    static var glassHighlight: Color { topHighlight }
    static var toolbarBackground: Color { surfaceSunken }
    static var controlFill: Color { surfaceRaised }
}

struct Keycap: View {
    var title: String
    var compact = false

    var body: some View {
        Text(title)
            .font(InkletTheme.Typography.keycap)
            .foregroundStyle(InkletTheme.secondaryLabel)
            .frame(minWidth: compact ? 18 : 20, minHeight: compact ? 18 : 20)
            .padding(.horizontal, compact ? 3 : 4)
            .background(InkletTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: InkletTheme.Radius.keycap))
            .overlay {
                RoundedRectangle(cornerRadius: InkletTheme.Radius.keycap)
                    .stroke(InkletTheme.strokeStrong)
            }
    }
}

struct InkletFieldModifier: ViewModifier {
    var isFocused = false

    func body(content: Content) -> some View {
        content
            .background(InkletTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: InkletTheme.Radius.small))
            .overlay {
                RoundedRectangle(cornerRadius: InkletTheme.Radius.small)
                    .stroke(isFocused ? InkletTheme.accent : InkletTheme.strokeStrong)
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
