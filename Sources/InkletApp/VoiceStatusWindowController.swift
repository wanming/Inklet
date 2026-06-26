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

private struct PromptModeSelectionDisplayItem {
    var title: String
    var subtitle: String?
    var selection: VoicePromptModeSelection
}

@MainActor
final class VoiceStatusWindowController: NSWindowController {
    private static let panelSize = NSSize(width: 220, height: 40)
    private static let selectionPanelWidth: CGFloat = 320
    private static let selectionRowHeight: CGFloat = 34
    private static let selectionMaxVisibleRows = 7
    private static let panelBottomOffset: CGFloat = 36
    private static let panelAlpha: CGFloat = 0.88
    private static let selectionPanelAlpha: CGFloat = 0.98
    private static let errorDismissDelay: TimeInterval = 2.5

    private let textField = NSTextField(labelWithString: "")
    private let closeButton = NSButton()
    private lazy var statusContentView = makeStatusContentView()
    private var promptModeSelectionContinuation: CheckedContinuation<VoicePromptModeSelection, Never>?
    private weak var promptModeSelectionListView: PromptModeSelectionListView?
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
        panel.contentView = statusContentView
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(_ status: VoiceInputStatus) {
        cancelScheduledDismiss()
        switch status {
        case .idle:
            completePromptModeSelection(.cancelled, shouldOrderOut: false)
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
        case .choosingPromptMode:
            shouldCancelOnClose = true
            lastStatusWasFallback = false
            show(message: L10n.text("voice.status.choosingPromptMode"))
        case .polishing:
            shouldCancelOnClose = true
            lastStatusWasFallback = false
            show(message: L10n.text("voice.status.polishing"))
        case .inserting:
            shouldCancelOnClose = true
            lastStatusWasFallback = false
            hideForTextInsertion()
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

    func selectPromptMode(
        transcript: String,
        modes: [PromptMode],
        defaultModeID: String
    ) async -> VoicePromptModeSelection {
        await withCheckedContinuation { continuation in
            completePromptModeSelection(.cancelled, shouldOrderOut: false)
            promptModeSelectionContinuation = continuation
            showPromptModeSelection(transcript: transcript, modes: modes, defaultModeID: defaultModeID)
        }
    }

    private func show(message: String, autoDismissAfter delay: TimeInterval? = nil) {
        if window?.contentView !== statusContentView {
            window?.contentView = statusContentView
        }
        promptModeSelectionListView = nil
        textField.stringValue = message
        guard let window else {
            return
        }

        window.alphaValue = Self.panelAlpha
        resetSize(of: window)
        position(window)
        didPositionWindow = true
        window.orderFrontRegardless()
        if let delay {
            scheduleDismiss(after: delay)
        }
    }

    private func showPromptModeSelection(transcript: String, modes: [PromptMode], defaultModeID: String) {
        guard let window else {
            completePromptModeSelection(.cancelled, shouldOrderOut: false)
            return
        }

        let selections = promptModeSelections(modes: modes, defaultModeID: defaultModeID)
        let visibleRows = min(selections.count, Self.selectionMaxVisibleRows)
        let panelHeight = 44 + CGFloat(visibleRows) * Self.selectionRowHeight + 14
        let panelSize = NSSize(width: Self.selectionPanelWidth, height: panelHeight)
        window.contentView = makePromptModeSelectionContentView(selections: selections)
        window.setContentSize(panelSize)
        window.contentView?.frame = NSRect(origin: .zero, size: panelSize)
        window.alphaValue = Self.selectionPanelAlpha
        position(window)
        didPositionWindow = true
        window.makeKeyAndOrderFront(nil)
        if let promptModeSelectionListView {
            window.makeFirstResponder(promptModeSelectionListView)
        }
    }

    private func promptModeSelections(
        modes: [PromptMode],
        defaultModeID: String
    ) -> [PromptModeSelectionDisplayItem] {
        var selections: [PromptModeSelectionDisplayItem] = modes.map { mode in
            let subtitle = mode.id == defaultModeID ? L10n.text("voice.promptMode.default") : nil
            return PromptModeSelectionDisplayItem(
                title: mode.localizedName,
                subtitle: subtitle,
                selection: .promptMode(mode.id)
            )
        }
        selections.append(PromptModeSelectionDisplayItem(
            title: L10n.text("voice.promptMode.rawTranscript"),
            subtitle: nil,
            selection: .rawTranscript
        ))
        return selections
    }

    private func makePromptModeSelectionContentView(
        selections: [PromptModeSelectionDisplayItem]
    ) -> NSView {
        promptModeSelectionListView = nil
        let visibleRows = min(selections.count, Self.selectionMaxVisibleRows)
        let panelHeight = 44 + CGFloat(visibleRows) * Self.selectionRowHeight + 14
        let panelSize = NSSize(width: Self.selectionPanelWidth, height: panelHeight)

        let container = DraggableVisualEffectView(frame: NSRect(origin: .zero, size: panelSize))
        container.material = .popover
        container.blendingMode = .behindWindow
        container.state = .active
        container.wantsLayer = true
        container.layer?.cornerRadius = 14
        container.layer?.cornerCurve = .continuous
        container.layer?.masksToBounds = true
        container.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor
        container.layer?.borderWidth = 0.5

        let titleField = NSTextField(labelWithString: L10n.text("voice.promptMode.title"))
        titleField.font = .systemFont(ofSize: 13, weight: .semibold)
        titleField.textColor = .labelColor
        titleField.translatesAutoresizingMaskIntoConstraints = false

        let close = NSButton()
        close.title = "×"
        close.bezelStyle = .inline
        close.isBordered = false
        close.font = .systemFont(ofSize: 15, weight: .regular)
        close.contentTintColor = .secondaryLabelColor
        close.target = self
        close.action = #selector(cancel)
        close.translatesAutoresizingMaskIntoConstraints = false

        let listView = PromptModeSelectionListView(items: selections, rowHeight: Self.selectionRowHeight)
        listView.onChoose = { [weak self] selection in
            self?.completePromptModeSelection(selection, shouldOrderOut: false)
        }
        listView.onCancel = { [weak self] in
            self?.cancel()
        }
        listView.autoresizingMask = [.width]
        promptModeSelectionListView = listView

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = selections.count > Self.selectionMaxVisibleRows
        scrollView.horizontalScrollElasticity = .none
        scrollView.borderType = .noBorder
        scrollView.scrollerStyle = .overlay
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.documentView = listView
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(titleField)
        container.addSubview(close)
        container.addSubview(scrollView)
        NSLayoutConstraint.activate([
            titleField.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            titleField.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            titleField.trailingAnchor.constraint(equalTo: close.leadingAnchor, constant: -8),

            close.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            close.centerYAnchor.constraint(equalTo: titleField.centerYAnchor),
            close.widthAnchor.constraint(equalToConstant: 18),
            close.heightAnchor.constraint(equalToConstant: 18),

            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            scrollView.topAnchor.constraint(equalTo: titleField.bottomAnchor, constant: 8),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10)
        ])
        listView.frame = NSRect(
            origin: .zero,
            size: NSSize(
                width: Self.selectionPanelWidth - 20,
                height: CGFloat(selections.count) * Self.selectionRowHeight
            )
        )
        return container
    }

    private func resetSize(of window: NSWindow) {
        window.setContentSize(Self.panelSize)
        window.contentView?.frame = NSRect(origin: .zero, size: Self.panelSize)
        window.contentView?.needsLayout = true
        window.contentView?.layoutSubtreeIfNeeded()
    }

    private func hideForTextInsertion() {
        completePromptModeSelection(.cancelled, shouldOrderOut: false)
        promptModeSelectionListView = nil
        window?.makeFirstResponder(nil)
        window?.orderOut(nil)
    }

    private func position(_ window: NSWindow) {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let visibleFrame = screen?.visibleFrame else {
            window.center()
            return
        }

        let windowSize = window.frame.size
        let origin = NSPoint(
            x: visibleFrame.midX - windowSize.width / 2,
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

    private func makeStatusContentView() -> NSView {
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
        textField.alignment = .left
        textField.lineBreakMode = .byTruncatingTail
        textField.maximumNumberOfLines = 1
        textField.setContentHuggingPriority(.required, for: .horizontal)
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
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
            textField.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -6),
            textField.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            closeButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            closeButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 18),
            closeButton.heightAnchor.constraint(equalToConstant: 18)
        ])
        return container
    }

    @objc private func cancel() {
        if promptModeSelectionContinuation != nil {
            completePromptModeSelection(.cancelled, shouldOrderOut: true)
            return
        }

        window?.orderOut(nil)
        guard shouldCancelOnClose else {
            return
        }

        onCancel?()
    }

    private func completePromptModeSelection(
        _ selection: VoicePromptModeSelection,
        shouldOrderOut: Bool
    ) {
        guard let continuation = promptModeSelectionContinuation else {
            return
        }

        promptModeSelectionContinuation = nil
        promptModeSelectionListView = nil
        if shouldOrderOut {
            window?.orderOut(nil)
        }
        continuation.resume(returning: selection)
    }
}

@MainActor
private final class PromptModeSelectionListView: NSView {
    private let items: [PromptModeSelectionDisplayItem]
    private let rowHeight: CGFloat
    private var state: VoicePromptModeSelectionMenuState
    private var hoveredIndex: Int?
    private var trackingArea: NSTrackingArea?

    var onChoose: ((VoicePromptModeSelection) -> Void)?
    var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }

    init(items: [PromptModeSelectionDisplayItem], rowHeight: CGFloat) {
        self.items = items
        self.rowHeight = rowHeight
        self.state = VoicePromptModeSelectionMenuState(selections: items.map(\.selection))
        super.init(frame: NSRect(
            origin: .zero,
            size: NSSize(width: 1, height: CGFloat(items.count) * rowHeight)
        ))
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.activeAlways, .inVisibleRect, .mouseMoved, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
        super.updateTrackingAreas()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        for index in items.indices {
            drawRow(at: index)
        }
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        hoveredIndex = rowIndex(at: point)
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        hoveredIndex = nil
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        guard let index = rowIndex(at: point),
              let selection = state.select(index: index) else {
            return
        }

        hoveredIndex = index
        needsDisplay = true
        onChoose?(selection)
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 126:
            state.moveSelectionUp()
            scrollSelectedRowToVisible()
            needsDisplay = true
        case 125:
            state.moveSelectionDown()
            scrollSelectedRowToVisible()
            needsDisplay = true
        case 36, 49, 76:
            chooseSelectedSelection()
        case 53:
            onCancel?()
        default:
            super.keyDown(with: event)
        }
    }

    private func drawRow(at index: Int) {
        let rowRect = rowRect(at: index)
        let isSelected = index == state.selectedIndex
        let isHovered = index == hoveredIndex

        if isSelected || isHovered {
            let fillColor = isSelected
                ? NSColor.controlAccentColor.withAlphaComponent(0.18)
                : NSColor.labelColor.withAlphaComponent(0.06)
            fillColor.setFill()
            NSBezierPath(roundedRect: rowRect, xRadius: 8, yRadius: 8).fill()
        }

        let item = items[index]
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: item.subtitle == nil ? .regular : .medium),
            .foregroundColor: NSColor.labelColor
        ]
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: NSColor.controlAccentColor
        ]

        let horizontalPadding: CGFloat = 12
        let subtitleRect = item.subtitle.map { subtitle in
            let subtitleSize = subtitle.size(withAttributes: subtitleAttributes)
            return NSRect(
                x: rowRect.maxX - subtitleSize.width - 18,
                y: rowRect.midY - 9,
                width: subtitleSize.width + 12,
                height: 18
            )
        }
        let titleRight = subtitleRect.map { $0.minX - 8 } ?? rowRect.maxX - horizontalPadding
        let titleRect = NSRect(
            x: rowRect.minX + horizontalPadding,
            y: rowRect.midY - 9,
            width: max(40, titleRight - rowRect.minX - horizontalPadding),
            height: 18
        )
        item.title.draw(
            with: titleRect,
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            attributes: titleAttributes
        )

        if let subtitle = item.subtitle, let subtitleRect {
            NSColor.controlAccentColor.withAlphaComponent(0.12).setFill()
            NSBezierPath(roundedRect: subtitleRect, xRadius: 6, yRadius: 6).fill()
            let subtitleTextRect = subtitleRect.insetBy(dx: 6, dy: 2)
            subtitle.draw(
                with: subtitleTextRect,
                options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                attributes: subtitleAttributes
            )
        }
    }

    private func rowRect(at index: Int) -> NSRect {
        NSRect(
            x: 4,
            y: CGFloat(index) * rowHeight + 2,
            width: bounds.width - 8,
            height: rowHeight - 4
        )
    }

    private func rowIndex(at point: NSPoint) -> Int? {
        guard bounds.contains(point) else {
            return nil
        }
        let index = Int(point.y / rowHeight)
        guard items.indices.contains(index) else {
            return nil
        }
        return index
    }

    private func chooseSelectedSelection() {
        guard let selection = state.selectedSelection else {
            return
        }
        onChoose?(selection)
    }

    private func scrollSelectedRowToVisible() {
        guard items.indices.contains(state.selectedIndex) else {
            return
        }

        guard let clipView = enclosingScrollView?.contentView else {
            return
        }

        let rowRect = rowRect(at: state.selectedIndex)
        let visibleRect = clipView.bounds
        let maxY = max(0, bounds.height - visibleRect.height)
        var targetY = visibleRect.origin.y
        if rowRect.minY < visibleRect.minY {
            targetY = rowRect.minY
        } else if rowRect.maxY > visibleRect.maxY {
            targetY = rowRect.maxY - visibleRect.height
        }
        targetY = min(max(0, targetY), maxY)

        let targetOrigin = NSPoint(x: 0, y: targetY)
        guard targetOrigin != visibleRect.origin else {
            return
        }
        clipView.scroll(to: targetOrigin)
        enclosingScrollView?.reflectScrolledClipView(clipView)
    }
}
