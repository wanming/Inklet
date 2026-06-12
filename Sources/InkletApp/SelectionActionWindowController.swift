import AppKit
import SwiftUI
import InkletCore

@MainActor
private final class SelectionActionPanel: NSPanel {
    var onEscape: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }

    override func keyDown(with event: NSEvent) {
        guard event.keyCode == 53 else {
            super.keyDown(with: event)
            return
        }

        onEscape?()
    }
}

@MainActor
final class SelectionActionWindowController: NSWindowController {
    var onTranslate: (() -> Void)?
    var onPronounce: (() -> Void)?
    var onCopyTranslation: (() -> Void)?
    var onRetryTranslation: (() -> Void)?
    var onDismiss: (() -> Void)?

    private var state: SelectionActionViewState = .menu(errorMessage: nil)
    private let panelWidth: CGFloat = 300
    private let minimumPanelHeight: CGFloat = 72

    init() {
        let panel = SelectionActionPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: minimumPanelHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.title = "Inklet Selection Actions"
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovableByWindowBackground = false
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]

        super.init(window: panel)

        panel.onEscape = { [weak self] in
            self?.onDismiss?()
        }
        render()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showMenu(at point: SelectionPoint) {
        state = .menu(errorMessage: nil)
        render()
        positionWindow(at: point)
        window?.makeKeyAndOrderFront(nil)
    }

    func showPronunciationError(_ message: String) {
        state = .menu(errorMessage: message)
        render()
    }

    func showNotice(_ message: String, at point: SelectionPoint) {
        state = .notice(message)
        render()
        positionWindow(at: point)
        window?.makeKeyAndOrderFront(nil)
    }

    func showTranslating() {
        state = .translating
        render()
    }

    func showTranslation(_ text: String) {
        state = .translationResult(text)
        render()
    }

    func showTranslationError(_ message: String) {
        state = .translationError(message)
        render()
    }

    func hidePanel() {
        window?.orderOut(nil)
    }

    private func render() {
        let hostingView = NSHostingView(rootView: SelectionActionView(
            state: state,
            onTranslate: { [weak self] in self?.onTranslate?() },
            onPronounce: { [weak self] in self?.onPronounce?() },
            onCopyTranslation: { [weak self] in self?.onCopyTranslation?() },
            onRetryTranslation: { [weak self] in self?.onRetryTranslation?() }
        ))
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = 12
        hostingView.layer?.cornerCurve = .continuous
        hostingView.layer?.masksToBounds = true
        window?.contentView = hostingView
        resizeToFittingHeight()
    }

    private func resizeToFittingHeight() {
        guard let window, let contentView = window.contentView else {
            return
        }

        let fittingSize = contentView.fittingSize
        let height = min(max(fittingSize.height, minimumPanelHeight), 260)
        var frame = window.frame
        let topY = frame.maxY
        frame.size = NSSize(width: panelWidth, height: height)
        frame.origin.y = topY - height
        window.setFrame(frame, display: true)
    }

    private func positionWindow(at point: SelectionPoint) {
        guard let window else {
            return
        }

        var frame = window.frame
        frame.origin = NSPoint(x: point.x + 8, y: point.y - frame.height - 8)

        if let screen = NSScreen.screens.first(where: { $0.visibleFrame.contains(NSPoint(x: point.x, y: point.y)) })
            ?? NSScreen.main {
            let visibleFrame = screen.visibleFrame
            frame.origin.x = min(max(frame.origin.x, visibleFrame.minX + 8), visibleFrame.maxX - frame.width - 8)
            frame.origin.y = min(max(frame.origin.y, visibleFrame.minY + 8), visibleFrame.maxY - frame.height - 8)
        }

        window.setFrame(frame, display: true)
    }
}
