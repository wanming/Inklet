import AppKit
import InkletCore

@MainActor
private final class VoiceStatusPanel: NSPanel {
    var onCancel: (() -> Void)?
    var onEscape: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

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
private final class DraggableVisualEffectView: NSVisualEffectView {
    override var mouseDownCanMoveWindow: Bool { true }
}

@MainActor
final class VoiceStatusWindowController: NSWindowController {
    private static let panelSize = NSSize(width: 220, height: 40)
    private static let panelBottomOffset: CGFloat = 36
    private static let panelAlpha: CGFloat = 0.88
    private static let errorDismissDelay: TimeInterval = 2.5

    private let textField = NSTextField(labelWithString: "")
    private let closeButton = NSButton()
    private var lastStatusWasFallback = false
    private var shouldCancelOnClose = false
    private var didPositionWindow = false
    private var dismissWorkItem: DispatchWorkItem?

    var onCancel: (() -> Void)? {
        didSet {
            (window as? VoiceStatusPanel)?.onCancel = onCancel
        }
    }

    init() {
        let panel = VoiceStatusPanel(
            contentRect: NSRect(origin: .zero, size: Self.panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .transient]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.alphaValue = Self.panelAlpha
        panel.isMovableByWindowBackground = true
        super.init(window: panel)
        panel.onEscape = { [weak self] in
            self?.cancel()
        }
        panel.contentView = makeContentView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(_ status: VoiceInputStatus) {
        cancelScheduledDismiss()
        switch status {
        case .idle:
            shouldCancelOnClose = false
            if lastStatusWasFallback {
                scheduleDismiss(after: 1.5)
            } else {
                window?.orderOut(nil)
            }
            lastStatusWasFallback = false
        case .listening:
            shouldCancelOnClose = true
            lastStatusWasFallback = false
            show(message: L10n.text("voice.status.listening"))
        case .transcribing:
            shouldCancelOnClose = true
            lastStatusWasFallback = false
            show(message: L10n.text("voice.status.transcribing"))
        case .polishing:
            shouldCancelOnClose = true
            lastStatusWasFallback = false
            show(message: L10n.text("voice.status.polishing"))
        case .inserting:
            shouldCancelOnClose = true
            lastStatusWasFallback = false
            show(message: L10n.text("voice.status.inserting"))
        case .fallbackInserted(let message):
            shouldCancelOnClose = false
            lastStatusWasFallback = true
            show(message: message, autoDismissAfter: Self.errorDismissDelay)
        case .error(let message):
            shouldCancelOnClose = false
            lastStatusWasFallback = false
            show(message: message, autoDismissAfter: Self.errorDismissDelay)
        }
    }

    private func show(message: String, autoDismissAfter delay: TimeInterval? = nil) {
        textField.stringValue = message
        guard let window else {
            return
        }

        resetSize(of: window)
        if !didPositionWindow {
            position(window)
            didPositionWindow = true
        }
        window.orderFrontRegardless()
        if let delay {
            scheduleDismiss(after: delay)
        }
    }

    private func resetSize(of window: NSWindow) {
        var frame = window.frame
        frame.size = Self.panelSize
        window.setFrame(frame, display: false)
        window.contentView?.frame = NSRect(origin: .zero, size: Self.panelSize)
    }

    private func position(_ window: NSWindow) {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let visibleFrame = screen?.visibleFrame else {
            window.center()
            return
        }

        let origin = NSPoint(
            x: visibleFrame.midX - Self.panelSize.width / 2,
            y: visibleFrame.minY + Self.panelBottomOffset
        )
        window.setFrameOrigin(origin)
    }

    private func scheduleDismiss(after delay: TimeInterval) {
        cancelScheduledDismiss()
        let workItem = DispatchWorkItem { [weak self] in
            self?.window?.orderOut(nil)
        }
        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func cancelScheduledDismiss() {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
    }

    private func makeContentView() -> NSView {
        let container = DraggableVisualEffectView(frame: NSRect(origin: .zero, size: Self.panelSize))
        container.material = .hudWindow
        container.blendingMode = .behindWindow
        container.state = .active
        container.wantsLayer = true
        container.layer?.cornerRadius = 13
        container.layer?.cornerCurve = .continuous
        container.layer?.masksToBounds = true

        let dot = NSTextField(labelWithString: "●")
        dot.textColor = .systemRed
        dot.font = .systemFont(ofSize: 11, weight: .semibold)
        dot.translatesAutoresizingMaskIntoConstraints = false

        textField.font = .systemFont(ofSize: 12, weight: .semibold)
        textField.lineBreakMode = .byTruncatingTail
        textField.maximumNumberOfLines = 1
        textField.translatesAutoresizingMaskIntoConstraints = false

        closeButton.title = "×"
        closeButton.bezelStyle = .inline
        closeButton.isBordered = false
        closeButton.target = self
        closeButton.action = #selector(cancel)
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(dot)
        container.addSubview(textField)
        container.addSubview(closeButton)
        NSLayoutConstraint.activate([
            dot.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            dot.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            textField.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 7),
            textField.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -6),
            textField.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            closeButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            closeButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 18),
            closeButton.heightAnchor.constraint(equalToConstant: 18)
        ])
        return container
    }

    @objc private func cancel() {
        window?.orderOut(nil)
        guard shouldCancelOnClose else {
            return
        }

        onCancel?()
    }
}
