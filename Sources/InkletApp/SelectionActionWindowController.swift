import AppKit
import Combine
import SwiftUI
import InkletCore

@MainActor
private final class SelectionActionPanel: NSPanel {
    private struct SelectionActionPanelDragState {
        let initialMouseLocation: NSPoint
        let initialWindowOrigin: NSPoint
        /// The press that started a selection bar drag, replayed as a click if the mouse never
        /// moves past the drag threshold.
        var pendingMouseDown: NSEvent?
    }

    var onEscape: (() -> Void)?
    var isBackgroundDraggingEnabled = false
    /// Lets a press anywhere on the panel, buttons included, drag it once it moves a few points.
    var isPressDraggingEnabled = false
    var backgroundDragExclusionRects: [NSRect] = []

    private var dragState: SelectionActionPanelDragState?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            if isPressDraggingEnabled {
                dragState = SelectionActionPanelDragState(
                    initialMouseLocation: NSEvent.mouseLocation,
                    initialWindowOrigin: frame.origin,
                    pendingMouseDown: event
                )
                return
            }
            if isBackgroundDraggingEnabled, isBackgroundDragPoint(event.locationInWindow) {
                dragState = SelectionActionPanelDragState(
                    initialMouseLocation: NSEvent.mouseLocation,
                    initialWindowOrigin: frame.origin
                )
                NSCursor.closedHand.set()
                return
            }
        case .leftMouseDragged:
            if var dragState {
                let mouseLocation = NSEvent.mouseLocation
                if dragState.pendingMouseDown != nil {
                    guard SelectionPanelDragRegions.hasPassedPressDragThreshold(
                        from: SelectionPoint(x: dragState.initialMouseLocation.x, y: dragState.initialMouseLocation.y),
                        to: SelectionPoint(x: mouseLocation.x, y: mouseLocation.y)
                    ) else {
                        return
                    }
                    dragState.pendingMouseDown = nil
                    self.dragState = dragState
                    NSCursor.closedHand.set()
                }
                let newOrigin = NSPoint(
                    x: dragState.initialWindowOrigin.x + mouseLocation.x - dragState.initialMouseLocation.x,
                    y: dragState.initialWindowOrigin.y + mouseLocation.y - dragState.initialMouseLocation.y
                )
                setFrameOrigin(newOrigin)
                return
            }
        case .leftMouseUp:
            if let dragState {
                self.dragState = nil
                if let pendingMouseDown = dragState.pendingMouseDown {
                    super.sendEvent(pendingMouseDown)
                    super.sendEvent(event)
                } else {
                    NSCursor.arrow.set()
                }
                return
            }
        default:
            break
        }

        super.sendEvent(event)
    }

    /// Drops a press that has not become a drag yet, so a content swap never receives it as a click.
    func discardPendingPress() {
        if dragState?.pendingMouseDown != nil {
            dragState = nil
        }
    }

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

    private func isBackgroundDragPoint(_ point: NSPoint) -> Bool {
        guard isBackgroundDraggingEnabled else {
            return false
        }

        let resizeEdgeWidth: CGFloat = 8
        guard point.x > resizeEdgeWidth,
              point.y > resizeEdgeWidth,
              point.x < frame.width - resizeEdgeWidth,
              point.y < frame.height - resizeEdgeWidth
        else {
            return false
        }

        return !backgroundDragExclusionRects.contains { $0.contains(point) }
    }
}

@MainActor
private final class SelectionActionHostingView<Content: View>: NSHostingView<Content> {
    override var mouseDownCanMoveWindow: Bool { false }
}

@MainActor
final class SelectionActionWindowController: NSWindowController {
    private static let translationPanelSizeKey = InkletPreferenceKeys.translationPanelSize
    private static let translationPanelMinimumSize = SelectionPanelSize(width: 300, height: 72)
    private static let translationPanelMaximumSize = SelectionPanelSize(width: 560, height: 520)
    private static let translationPanelDefaultMaximumHeight: Double = 360

    var onTranslate: (() -> Void)?
    var onPronounce: (() -> Void)?
    var onPronounceOriginal: (() -> Void)?
    var onPronounceTranslation: (() -> Void)?
    var onCopyTranslation: (() -> Void)?
    var onRetryTranslation: (() -> Void)?
    var onRunPromptMode: ((String) -> Void)?
    var onDismiss: (() -> Void)?

    var isPanelVisible: Bool {
        window?.isVisible == true
    }

    private var state: SelectionActionViewState = .menu(errorMessage: nil, feedback: nil)
    private var menuItems = SelectionMenuItem.defaults
    private var resultKind = SelectionActionResultKind.translation
    private let panelWidth: CGFloat = 300
    private let minimumPanelHeight: CGFloat = 36
    // Wide enough for four menu buttons with truncated prompt mode names.
    private let maximumMenuPanelWidth: CGFloat = 600
    private var hasUserResizedTranslationPanel = false
    private var isProgrammaticResize = false
    private var rememberedTranslationPanelSize: SelectionPanelSize?
    private var languageSubscription: AnyCancellable?

    init() {
        let panel = SelectionActionPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: minimumPanelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = L10n.text("settings.section.selectionActions")
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovableByWindowBackground = false
        panel.isReleasedWhenClosed = false
        panel.level = .popUpMenu
        panel.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
        rememberedTranslationPanelSize = Self.loadRememberedTranslationPanelSize()

        super.init(window: panel)

        panel.delegate = self
        panel.onEscape = { [weak self] in
            self?.onDismiss?()
        }
        render()
        languageSubscription = NotificationCenter.default.publisher(for: .inkletLanguageDidChange)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.render()
                }
            }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Sets the buttons for the next `showMenu`.
    func setMenuItems(_ items: [SelectionMenuItem]) {
        menuItems = items.isEmpty ? SelectionMenuItem.defaults : items
    }

    func showMenu(at point: SelectionPoint) {
        hasUserResizedTranslationPanel = false
        resultKind = .translation
        state = .menu(errorMessage: nil, feedback: nil)
        render()
        positionWindow(at: point)
        focusPanel()
        if let window {
            SelectionActionDiagnostics.log(
                "show menu frame=\(NSStringFromRect(window.frame)) visible=\(window.isVisible)"
            )
        }
    }

    func restoreMenu() {
        state = .menu(errorMessage: nil, feedback: nil)
        render()
    }

    func showPronunciationError(_ message: String) {
        state = .menu(errorMessage: message, feedback: nil)
        render()
    }

    func showPreparingPronunciation() {
        state = .menu(errorMessage: nil, feedback: .loadingMenuPronunciation)
        render()
    }

    func showPlayingPronunciation() {
        state = .menu(errorMessage: nil, feedback: .playingMenuPronunciation)
        render()
    }

    func showNotice(_ message: String, at point: SelectionPoint) {
        hasUserResizedTranslationPanel = false
        state = .notice(message)
        render()
        positionWindow(at: point)
        focusPanel()
        if let window {
            SelectionActionDiagnostics.log(
                "show notice frame=\(NSStringFromRect(window.frame)) visible=\(window.isVisible)"
            )
        }
    }

    func showTranslating() {
        state = .menu(errorMessage: nil, feedback: .loadingMenuTranslation)
        render()
    }

    func showRunningPromptMode(_ modeID: String) {
        state = .menu(errorMessage: nil, feedback: .loadingMenuPromptMode(modeID))
        render()
    }

    /// Shows a result. `kind` is kept across later calls that only update feedback.
    func showTranslation(
        _ text: String,
        errorMessage: String? = nil,
        feedback: SelectionActionFeedback? = nil,
        kind: SelectionActionResultKind? = nil
    ) {
        if translationText(for: state) != text {
            hasUserResizedTranslationPanel = false
        }
        if let kind {
            resultKind = kind
        }
        state = .translationResult(text, errorMessage: errorMessage, feedback: feedback)
        render()
    }

    func showTranslationError(_ message: String) {
        hasUserResizedTranslationPanel = false
        state = .translationError(message)
        render()
    }

    func hidePanel() {
        window?.orderOut(nil)
    }

    private func render() {
        window?.title = L10n.text("settings.section.selectionActions")
        configureWindowInteraction(for: state)

        // The hosting view sets the window's minimum and maximum size from its content, so the
        // result panel's limits go on the content too.
        let minimumSize = isTranslationResultState ? Self.translationPanelMinimumSize : nil
        let maximumSize = isTranslationResultState ? Self.translationPanelMaximumSize : nil
        let hostingView = SelectionActionHostingView(rootView: SelectionActionView(
            state: state,
            menuItems: menuItems,
            resultKind: resultKind,
            onTranslate: { [weak self] in self?.onTranslate?() },
            onPronounce: { [weak self] in self?.onPronounce?() },
            onPronounceOriginal: { [weak self] in self?.onPronounceOriginal?() },
            onPronounceTranslation: { [weak self] in self?.onPronounceTranslation?() },
            onCopyTranslation: { [weak self] in self?.onCopyTranslation?() },
            onRetryTranslation: { [weak self] in self?.onRetryTranslation?() },
            onRunPromptMode: { [weak self] modeID in self?.onRunPromptMode?(modeID) },
            onShowMoreActions: { [weak self] items in self?.showMoreActionsMenu(items) }
        )
        .frame(
            minWidth: minimumSize.map { CGFloat($0.width) },
            maxWidth: maximumSize.map { CGFloat($0.width) },
            minHeight: minimumSize.map { CGFloat($0.height) },
            maxHeight: maximumSize.map { CGFloat($0.height) }
        ))
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = 12
        hostingView.layer?.cornerCurve = .continuous
        hostingView.layer?.masksToBounds = true
        // Installing and measuring the hosting view can resize the window to fit its content;
        // that is not a user resize.
        let wasProgrammaticResize = isProgrammaticResize
        isProgrammaticResize = true
        (window as? SelectionActionPanel)?.discardPendingPress()
        window?.contentView = hostingView
        resizeToPreferredSize()
        isProgrammaticResize = wasProgrammaticResize
        updateBackgroundDragExclusionRects()
    }

    private func showMoreActionsMenu(_ items: [SelectionMenuItem]) {
        let menu = NSMenu()
        for item in items {
            let menuItem = SelectionMenuActionItem(title: item.title) { [weak self] in
                self?.performMenuAction(item.action)
            }
            menuItem.image = NSImage(systemSymbolName: item.systemImage, accessibilityDescription: nil)
            menu.addItem(menuItem)
        }
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    private func performMenuAction(_ action: SelectionMenuAction) {
        switch action {
        case .translate:
            onTranslate?()
        case .pronounce:
            onPronounce?()
        case .promptMode(let modeID):
            onRunPromptMode?(modeID)
        }
    }

    private func resizeToPreferredSize() {
        guard let window, let contentView = window.contentView else {
            return
        }

        if isTranslationResultState, hasUserResizedTranslationPanel {
            return
        }

        let fittingSize = contentView.fittingSize
        let size = preferredPanelSize(
            fittingSize: SelectionPanelSize(width: fittingSize.width, height: fittingSize.height)
        )
        var frame = window.frame
        let topY = frame.maxY
        frame.size = NSSize(width: size.width, height: size.height)
        frame.origin.y = topY - frame.height
        setWindowFrame(frame)
        keepWindowVisible()
    }

    private func preferredPanelSize(fittingSize: SelectionPanelSize) -> SelectionPanelSize {
        if case .translationResult(let text, _, _) = state {
            return SelectionPanelSizing.translationResultSize(
                textLength: text.count,
                rememberedSize: rememberedTranslationPanelSize,
                minimumSize: Self.translationPanelMinimumSize,
                maximumSize: Self.translationPanelMaximumSize,
                defaultMaximumHeight: Self.translationPanelDefaultMaximumHeight,
                contentHeight: { [self] width in Double(translationResultContentHeight(width: CGFloat(width))) }
            )
        }

        let maximumWidth: CGFloat = if case .menu = state { maximumMenuPanelWidth } else { 320 }
        return SelectionPanelSize(
            width: min(max(fittingSize.width, 120), maximumWidth),
            height: min(max(fittingSize.height, minimumPanelHeight), 260)
        )
    }

    /// The result's full height at `width`, measured with the text unscrolled, so the panel fits it.
    private func translationResultContentHeight(width: CGFloat) -> CGFloat {
        let measuringView = NSHostingView(rootView: SelectionActionView(
            state: state,
            menuItems: menuItems,
            resultKind: resultKind,
            measuresFullResult: true,
            onTranslate: {}, onPronounce: {}, onPronounceOriginal: {},
            onPronounceTranslation: {}, onCopyTranslation: {}, onRetryTranslation: {}
        )
        .frame(width: width))
        return measuringView.fittingSize.height
    }

    private func setWindowFrame(_ frame: NSRect) {
        guard let window else {
            return
        }

        let wasProgrammaticResize = isProgrammaticResize
        isProgrammaticResize = true
        window.setFrame(frame, display: true)
        isProgrammaticResize = wasProgrammaticResize
    }

    private func positionWindow(at point: SelectionPoint) {
        guard let window else {
            return
        }

        var frame = window.frame

        if let screen = NSScreen.screens.first(where: { $0.visibleFrame.contains(NSPoint(x: point.x, y: point.y)) })
            ?? NSScreen.main {
            let visibleFrame = screen.visibleFrame
            let origin = SelectionPanelPlacement.origin(
                forPanelSize: SelectionPanelSize(width: frame.width, height: frame.height),
                near: point,
                in: SelectionScreenFrame(
                    x: visibleFrame.minX,
                    y: visibleFrame.minY,
                    width: visibleFrame.width,
                    height: visibleFrame.height
                )
            )
            frame.origin = NSPoint(x: origin.x, y: origin.y)
        }

        setWindowFrame(frame)
        updateBackgroundDragExclusionRects()
    }

    private func focusPanel() {
        window?.orderFrontRegardless()
    }

    private var isTranslationResultState: Bool {
        if case .translationResult = state {
            return true
        }
        return false
    }

    private func translationText(for state: SelectionActionViewState) -> String? {
        if case .translationResult(let text, _, _) = state {
            return text
        }
        return nil
    }

    private func configureWindowInteraction(for state: SelectionActionViewState) {
        guard let window, let panel = window as? SelectionActionPanel else {
            return
        }

        window.isMovableByWindowBackground = false
        switch state {
        case .translationResult:
            panel.isPressDraggingEnabled = false
            panel.isBackgroundDraggingEnabled = true
            window.styleMask.insert(.resizable)
            window.minSize = NSSize(
                width: Self.translationPanelMinimumSize.width,
                height: Self.translationPanelMinimumSize.height
            )
            window.maxSize = NSSize(
                width: Self.translationPanelMaximumSize.width,
                height: Self.translationPanelMaximumSize.height
            )
        default:
            panel.isPressDraggingEnabled = true
            panel.isBackgroundDraggingEnabled = false
            panel.backgroundDragExclusionRects = []
            window.styleMask.remove(.resizable)
            window.minSize = NSSize(width: 120, height: minimumPanelHeight)
            window.maxSize = NSSize(width: maximumMenuPanelWidth, height: 260)
        }
    }

    private func updateBackgroundDragExclusionRects() {
        guard let panel = window as? SelectionActionPanel else {
            return
        }

        guard isTranslationResultState else {
            panel.backgroundDragExclusionRects = []
            return
        }

        let regions = SelectionPanelDragRegions.translationResultRegions(
            panelSize: SelectionPanelSize(width: panel.frame.width, height: panel.frame.height)
        )
        panel.backgroundDragExclusionRects = regions.exclusionRects.map { rect in
            NSRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
        }
    }

    private func keepWindowVisible() {
        guard let window,
              let screen = window.screen ?? NSScreen.main
        else {
            return
        }

        var frame = window.frame
        let visibleFrame = screen.visibleFrame
        frame.origin.x = min(max(frame.origin.x, visibleFrame.minX + 8), visibleFrame.maxX - frame.width - 8)
        frame.origin.y = min(max(frame.origin.y, visibleFrame.minY + 8), visibleFrame.maxY - frame.height - 8)
        setWindowFrame(frame)
    }

    private static func loadRememberedTranslationPanelSize(
        userDefaults: UserDefaults = .standard
    ) -> SelectionPanelSize? {
        guard let value = userDefaults.dictionary(forKey: translationPanelSizeKey),
              let width = numericValue(value["width"]),
              let height = numericValue(value["height"])
        else {
            return nil
        }

        return clampedRememberedTranslationPanelSize(SelectionPanelSize(width: width, height: height))
    }

    private func saveRememberedTranslationPanelSize(_ size: NSSize) {
        // A height that cuts the text off is a limit the user chose. A panel dragged taller than
        // its text only says how far later results may grow, so a short result never caps them
        // below the default.
        let cutsOffText = size.height < translationResultContentHeight(width: size.width) - 1
        let maximumHeight = cutsOffText
            ? size.height
            : max(size.height, Self.translationPanelDefaultMaximumHeight)
        let clampedSize = Self.clampedRememberedTranslationPanelSize(
            SelectionPanelSize(width: size.width, height: maximumHeight)
        )
        rememberedTranslationPanelSize = clampedSize
        UserDefaults.standard.set(
            ["width": clampedSize.width, "height": clampedSize.height],
            forKey: Self.translationPanelSizeKey
        )
    }

    private static func numericValue(_ value: Any?) -> Double? {
        if let value = value as? Double {
            return value
        }
        return (value as? NSNumber)?.doubleValue
    }

    /// The remembered width is the result panel's width; the remembered height is how tall it
    /// may grow before the text scrolls.
    private static func clampedRememberedTranslationPanelSize(
        _ size: SelectionPanelSize
    ) -> SelectionPanelSize {
        SelectionPanelSizing.clamped(
            size,
            minimumSize: translationPanelMinimumSize,
            maximumSize: translationPanelMaximumSize
        )
    }
}

extension SelectionActionWindowController: NSWindowDelegate {
    func windowDidResize(_ notification: Notification) {
        guard !isProgrammaticResize, isTranslationResultState else {
            updateBackgroundDragExclusionRects()
            return
        }

        hasUserResizedTranslationPanel = true
        // A drag saves once when it ends, not on every frame.
        if let window = notification.object as? NSWindow, !window.inLiveResize {
            saveRememberedTranslationPanelSize(window.frame.size)
        }
        updateBackgroundDragExclusionRects()
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        guard hasUserResizedTranslationPanel, isTranslationResultState,
              let window = notification.object as? NSWindow
        else {
            return
        }

        saveRememberedTranslationPanelSize(window.frame.size)
    }
}

private final class SelectionMenuActionItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(runHandler), keyEquivalent: "")
        target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func runHandler() {
        handler()
    }
}
