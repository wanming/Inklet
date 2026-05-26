import AppKit
import InkletCore

@MainActor
private final class VoiceStatusPanel: NSPanel {
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        guard event.keyCode == 53 else {
            super.keyDown(with: event)
            return
        }

        onCancel?()
    }
}

@MainActor
final class VoiceStatusWindowController: NSWindowController {
    private let textField = NSTextField(labelWithString: "")
    private let closeButton = NSButton()
    private var lastStatusWasFallback = false

    var onCancel: (() -> Void)? {
        didSet {
            (window as? VoiceStatusPanel)?.onCancel = onCancel
        }
    }

    init() {
        let panel = VoiceStatusPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 64),
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
        super.init(window: panel)
        panel.contentView = makeContentView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(_ status: VoiceInputStatus) {
        switch status {
        case .idle:
            if lastStatusWasFallback {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    self?.window?.orderOut(nil)
                }
            } else {
                window?.orderOut(nil)
            }
            lastStatusWasFallback = false
        case .listening:
            lastStatusWasFallback = false
            show(message: L10n.text("voice.status.listening"))
        case .transcribing:
            lastStatusWasFallback = false
            show(message: L10n.text("voice.status.transcribing"))
        case .polishing:
            lastStatusWasFallback = false
            show(message: L10n.text("voice.status.polishing"))
        case .inserting:
            lastStatusWasFallback = false
            show(message: L10n.text("voice.status.inserting"))
        case .fallbackInserted(let message):
            lastStatusWasFallback = true
            show(message: message)
        case .error(let message):
            lastStatusWasFallback = false
            show(message: message)
        }
    }

    private func show(message: String) {
        textField.stringValue = message
        guard let window else {
            return
        }

        position(window)
        window.orderFrontRegardless()
    }

    private func position(_ window: NSWindow) {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let visibleFrame = screen?.visibleFrame else {
            window.center()
            return
        }

        let frame = window.frame
        let origin = NSPoint(
            x: visibleFrame.midX - frame.width / 2,
            y: visibleFrame.maxY - frame.height - 72
        )
        window.setFrameOrigin(origin)
    }

    private func makeContentView() -> NSView {
        let container = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 360, height: 64))
        container.material = .hudWindow
        container.blendingMode = .behindWindow
        container.state = .active
        container.wantsLayer = true
        container.layer?.cornerRadius = 20
        container.layer?.cornerCurve = .continuous

        let dot = NSTextField(labelWithString: "●")
        dot.textColor = .systemRed
        dot.font = .systemFont(ofSize: 16, weight: .semibold)
        dot.translatesAutoresizingMaskIntoConstraints = false

        textField.font = .systemFont(ofSize: 14, weight: .semibold)
        textField.lineBreakMode = .byTruncatingTail
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
            dot.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 18),
            dot.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            textField.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 10),
            textField.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -8),
            textField.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            closeButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            closeButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 20),
            closeButton.heightAnchor.constraint(equalToConstant: 20)
        ])
        return container
    }

    @objc private func cancel() {
        onCancel?()
    }
}
