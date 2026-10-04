import AppKit
import SwiftUI
import InkletCore

final class InkletTextContainerView: NSView {
    let scrollView = NSScrollView()
    let placeholderLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.font = .systemFont(ofSize: 14)
        placeholderLabel.textColor = .placeholderTextColor
        placeholderLabel.lineBreakMode = .byTruncatingTail
        placeholderLabel.maximumNumberOfLines = 1
        placeholderLabel.isEditable = false
        placeholderLabel.isSelectable = false
        placeholderLabel.backgroundColor = .clear
        placeholderLabel.drawsBackground = false

        addSubview(scrollView)
        addSubview(placeholderLabel)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            placeholderLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            placeholderLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            placeholderLabel.topAnchor.constraint(equalTo: topAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @MainActor
    func updatePlaceholderVisibility() {
        let textView = scrollView.documentView as? NSTextView
        placeholderLabel.isHidden = placeholderLabel.stringValue.isEmpty
            || textView?.string.isEmpty == false
            || textView?.hasMarkedText() == true
    }
}

private final class InkletNativeTextView: NSTextView {
    var onInputStateChange: (() -> Void)?
    var onEscapeKeyDown: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        guard event.keyCode == 53, !hasMarkedText() else {
            super.keyDown(with: event)
            return
        }

        onEscapeKeyDown?()
    }

    override func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        super.setMarkedText(string, selectedRange: selectedRange, replacementRange: replacementRange)
        onInputStateChange?()
    }

    override func unmarkText() {
        super.unmarkText()
        onInputStateChange?()
    }

    override func insertText(_ insertString: Any, replacementRange: NSRange) {
        super.insertText(insertString, replacementRange: replacementRange)
        onInputStateChange?()
    }
}

struct InkletTextView: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String?
    var isEditable: Bool
    var onSubmit: (() -> Void)?
    var onInsertOriginal: (() -> Void)?
    var onEscape: (() -> Void)?
    var onTextViewAttachment: ((InkletTextViewAttachmentEvent) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            onSubmit: onSubmit,
            onInsertOriginal: onInsertOriginal,
            onEscape: onEscape,
            onTextViewAttachment: onTextViewAttachment
        )
    }

    func makeNSView(context: Context) -> InkletTextContainerView {
        let container = InkletTextContainerView()
        let scrollView = container.scrollView
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.contentInsets = NSEdgeInsetsZero
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.horizontalScrollElasticity = .none

        let textView = InkletNativeTextView()
        textView.string = text
        textView.delegate = context.coordinator
        textView.onInputStateChange = { [weak coordinator = context.coordinator, weak textView, weak container] in
            guard let textView else {
                return
            }
            coordinator?.syncText(from: textView)
            container?.updatePlaceholderVisibility()
        }
        textView.onEscapeKeyDown = { [weak coordinator = context.coordinator] in
            coordinator?.onEscape?()
        }
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesFindBar = false
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.font = .systemFont(ofSize: 14)
        textView.textColor = .labelColor
        textView.insertionPointColor = .controlAccentColor
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        scrollView.documentView = textView
        context.coordinator.textView = textView
        onTextViewAttachment?(.attach(textView))
        container.placeholderLabel.stringValue = placeholder ?? ""
        container.updatePlaceholderVisibility()
        return container
    }

    func updateNSView(_ container: InkletTextContainerView, context: Context) {
        let scrollView = container.scrollView
        guard let textView = scrollView.documentView as? NSTextView else {
            return
        }

        context.coordinator.text = $text
        context.coordinator.onSubmit = onSubmit
        context.coordinator.onInsertOriginal = onInsertOriginal
        context.coordinator.onEscape = onEscape
        context.coordinator.onTextViewAttachment = onTextViewAttachment
        context.coordinator.textView = textView
        onTextViewAttachment?(.attach(textView))

        textView.isEditable = isEditable
        textView.font = .systemFont(ofSize: 14)
        textView.textColor = .labelColor
        textView.insertionPointColor = .controlAccentColor
        container.placeholderLabel.stringValue = placeholder ?? ""

        if textView.isEditable, !textView.hasMarkedText(), textView.string != text {
            textView.string = text
        }
        container.updatePlaceholderVisibility()
    }

    static func dismantleNSView(
        _ container: InkletTextContainerView,
        coordinator: Coordinator
    ) {
        if let textView = container.scrollView.documentView as? NSTextView {
            coordinator.onTextViewAttachment?(.detach(textView))
        }
        coordinator.textView = nil
    }

    final class Coordinator: NSObject, NSTextViewDelegate, @unchecked Sendable {
        var text: Binding<String>
        var onSubmit: (() -> Void)?
        var onInsertOriginal: (() -> Void)?
        var onEscape: (() -> Void)?
        var onTextViewAttachment: ((InkletTextViewAttachmentEvent) -> Void)?
        weak var textView: NSTextView?

        init(
            text: Binding<String>,
            onSubmit: (() -> Void)?,
            onInsertOriginal: (() -> Void)?,
            onEscape: (() -> Void)?,
            onTextViewAttachment: ((InkletTextViewAttachmentEvent) -> Void)?
        ) {
            self.text = text
            self.onSubmit = onSubmit
            self.onInsertOriginal = onInsertOriginal
            self.onEscape = onEscape
            self.onTextViewAttachment = onTextViewAttachment
            super.init()
        }

        @MainActor
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }

            syncText(from: textView)
            textView.enclosingScrollView?.superview
                .flatMap { $0 as? InkletTextContainerView }?
                .updatePlaceholderVisibility()
        }

        @MainActor
        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }

            textView.enclosingScrollView?.superview
                .flatMap { $0 as? InkletTextContainerView }?
                .updatePlaceholderVisibility()
        }

        @MainActor
        func syncText(from textView: NSTextView) {
            text.wrappedValue = textView.string
        }

        @MainActor
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            guard !textView.hasMarkedText() else {
                return false
            }

            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                onEscape?()
                return true
            }

            guard commandSelector == #selector(NSResponder.insertNewline(_:))
                    || commandSelector == #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:))
            else {
                return false
            }

            let modifiers = NSApp.currentEvent?.modifierFlags.intersection(.deviceIndependentFlagsMask) ?? []
            if modifiers.contains(.command) {
                onInsertOriginal?()
                return true
            }

            if modifiers.contains(.shift) || modifiers.contains(.option) {
                return false
            }

            onSubmit?()
            return true
        }
    }
}

private extension NSView {
    var descendantTextViews: [NSTextView] {
        var textViews: [NSTextView] = []
        if let textView = self as? NSTextView {
            textViews.append(textView)
        }

        for subview in subviews {
            textViews.append(contentsOf: subview.descendantTextViews)
        }

        return textViews
    }
}

struct PopoverKeyEventHandler: NSViewRepresentable {
    let route: WritingPopoverSessionState.Route
    let onSubmit: () -> Void
    let onInsertOriginal: () -> Void
    let onEscape: () -> Void
    let onCycleMode: (Int) -> Void
    let onMoveModeHighlight: (Int) -> Void
    let onCommitMode: () -> Void
    let onCopyResult: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.route = route
        context.coordinator.onSubmit = onSubmit
        context.coordinator.onInsertOriginal = onInsertOriginal
        context.coordinator.onEscape = onEscape
        context.coordinator.onCycleMode = onCycleMode
        context.coordinator.onMoveModeHighlight = onMoveModeHighlight
        context.coordinator.onCommitMode = onCommitMode
        context.coordinator.onCopyResult = onCopyResult
        context.coordinator.attach(to: nsView)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.detach()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            route: route,
            onSubmit: onSubmit,
            onInsertOriginal: onInsertOriginal,
            onEscape: onEscape,
            onCycleMode: onCycleMode,
            onMoveModeHighlight: onMoveModeHighlight,
            onCommitMode: onCommitMode,
            onCopyResult: onCopyResult
        )
    }

    @MainActor
    final class Coordinator {
        var route: WritingPopoverSessionState.Route
        var onSubmit: () -> Void
        var onInsertOriginal: () -> Void
        var onEscape: () -> Void
        var onCycleMode: (Int) -> Void
        var onMoveModeHighlight: (Int) -> Void
        var onCommitMode: () -> Void
        var onCopyResult: () -> Void
        private weak var view: NSView?
        private var monitor: Any?

        init(
            route: WritingPopoverSessionState.Route,
            onSubmit: @escaping () -> Void,
            onInsertOriginal: @escaping () -> Void,
            onEscape: @escaping () -> Void,
            onCycleMode: @escaping (Int) -> Void,
            onMoveModeHighlight: @escaping (Int) -> Void,
            onCommitMode: @escaping () -> Void,
            onCopyResult: @escaping () -> Void
        ) {
            self.route = route
            self.onSubmit = onSubmit
            self.onInsertOriginal = onInsertOriginal
            self.onEscape = onEscape
            self.onCycleMode = onCycleMode
            self.onMoveModeHighlight = onMoveModeHighlight
            self.onCommitMode = onCommitMode
            self.onCopyResult = onCopyResult
        }

        func detach() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        func attach(to view: NSView) {
            self.view = view
            guard monitor == nil else { return }

            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.handle(event) ?? event
            }
        }

        private func handle(_ event: NSEvent) -> NSEvent? {
            guard let window = view?.window,
                  event.window === window,
                  window.isKeyWindow
            else {
                return event
            }

            let action = WritingPopoverKeyboardPolicy.action(
                route: route,
                keyCode: event.keyCode,
                modifiers: keyboardModifiers(from: event.modifierFlags),
                isComposingText: isComposingText
            )

            switch action {
            case .passThrough:
                return event
            case .consume:
                return nil
            case .escape:
                onEscape()
                return nil
            case .moveHighlight(let offset):
                onMoveModeHighlight(offset)
                return nil
            case .commitMode:
                onCommitMode()
                return nil
            case .cycleMode(let direction):
                onCycleMode(direction)
                return nil
            case .submit:
                onSubmit()
                return nil
            case .insertOriginal:
                onInsertOriginal()
                return nil
            case .copyResult:
                onCopyResult()
                return nil
            }
        }

        private var isComposingText: Bool {
            guard let responder = view?.window?.firstResponder as? NSTextInputClient else {
                return false
            }

            return responder.hasMarkedText()
        }

        private func keyboardModifiers(
            from modifiers: NSEvent.ModifierFlags
        ) -> WritingPopoverKeyboardModifiers {
            var keyboardModifiers: WritingPopoverKeyboardModifiers = []
            if modifiers.contains(.command) {
                keyboardModifiers.insert(.command)
            }
            if modifiers.contains(.shift) {
                keyboardModifiers.insert(.shift)
            }
            if modifiers.contains(.option) {
                keyboardModifiers.insert(.option)
            }
            if modifiers.contains(.control) {
                keyboardModifiers.insert(.control)
            }
            return keyboardModifiers
        }
    }
}
