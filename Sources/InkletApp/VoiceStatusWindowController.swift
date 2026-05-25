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
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 54),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
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

        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeContentView() -> NSView {
        let container = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 280, height: 54))
        container.material = .hudWindow
        container.blendingMode = .behindWindow
        container.state = .active
        container.wantsLayer = true
        container.layer?.cornerRadius = 18
        container.layer?.cornerCurve = .continuous

        let dot = NSTextField(labelWithString: "●")
        dot.textColor = .systemRed
        dot.font = .systemFont(ofSize: 14, weight: .semibold)
        dot.translatesAutoresizingMaskIntoConstraints = false

        textField.font = .systemFont(ofSize: 13, weight: .medium)
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
