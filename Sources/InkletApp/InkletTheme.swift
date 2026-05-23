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
                    .stroke(InkletTheme.subtleBorder)
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
                    .stroke(isFocused ? InkletTheme.primary.opacity(0.75) : InkletTheme.subtleBorder)
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
