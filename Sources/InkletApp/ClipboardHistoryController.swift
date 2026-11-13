import AppKit
import ApplicationServices
import SwiftUI
import InkletCore

extension Notification.Name {
    /// Posted by Settings after a clipboard history setting changes.
    static let inkletClipboardHistorySettingsDidChange = Notification.Name("InkletClipboardHistorySettingsDidChange")
    /// Posted by Settings to remove every unpinned clipboard history item.
    static let inkletClipboardHistoryClearRequested = Notification.Name("InkletClipboardHistoryClearRequested")
}

/// The clipboard history settings, kept in user defaults and edited in Settings › Clipboard.
enum ClipboardHistorySettings {
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: InkletPreferenceKeys.clipboardHistoryEnabled) as? Bool
            ?? ClipboardHistoryDefaults.isEnabled
    }

    static var hotkey: String {
        let stored = UserDefaults.standard.string(forKey: InkletPreferenceKeys.clipboardHistoryHotkey) ?? ""
        return stored.isEmpty ? ClipboardHistoryDefaults.hotkey : stored
    }

    static var retention: ClipboardHistoryRetention {
        ClipboardHistoryRetention.stored(
            UserDefaults.standard.string(forKey: InkletPreferenceKeys.clipboardHistoryRetention)
        )
    }
}

/// Watches the pasteboard for copies, keeps them in clipboard history, and shows the history
/// panel on its shortcut. Pressing Return in the panel pastes the item into the app the person
/// was using.
@MainActor
final class ClipboardHistoryController: NSObject, NSWindowDelegate {
    private static let pollInterval: TimeInterval = 0.5

    private let store: ClipboardHistoryStore
    private let pasteboard: NSPasteboard = .general
    private let hotkeyManager: GlobalHotkeyManager
    private let model: ClipboardHistoryPanelModel
    private var panel: ClipboardHistoryPanel?
    private var pollTimer: Timer?
    private var lastChangeCount: Int
    private var targetApplication: NSRunningApplication?
    private var observers: [NSObjectProtocol] = []
    private var isStarted = false
    private var isSuspended = false
    private var isRecordingHotkey = false
    private var pasteTask: Task<Void, Never>?

    var onOpenSettings: (() -> Void)?

    init(storagePaths: InkletStoragePaths) {
        let store = ClipboardHistoryStore(
            fileURL: storagePaths.clipboardHistoryFileURL,
            imagesDirectoryURL: storagePaths.clipboardImagesDirectoryURL
        )
        self.store = store
        self.hotkeyManager = GlobalHotkeyManager()
        self.model = ClipboardHistoryPanelModel(store: store)
        self.lastChangeCount = NSPasteboard.general.changeCount
        super.init()

        model.onPaste = { [weak self] item in self?.paste(item) }
        model.onCopy = { [weak self] item in self?.copy(item) }
        model.onClose = { [weak self] in self?.hide() }
        model.onOpenSettings = { [weak self] in
            self?.hide()
            self?.onOpenSettings?()
        }
    }

    var hotkeyDisplay: String {
        ClipboardHistorySettings.hotkey
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        store.load()
        store.prune(retention: ClipboardHistorySettings.retention)
        lastChangeCount = pasteboard.changeCount
        PasteboardOwnership.shared.willClaim = { [weak self] in
            self?.pollPasteboard()
        }

        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: .inkletClipboardHistorySettingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.applySettings()
            }
        })
        observers.append(center.addObserver(
            forName: .inkletClipboardHistoryClearRequested,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.store.clearUnpinned()
            }
        })
        observers.append(center.addObserver(
            forName: .hotkeyRecordingDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let isRecording = notification.userInfo?["isRecording"] as? Bool ?? false
            MainActor.assumeIsolated {
                self?.isRecordingHotkey = isRecording
                self?.registerHotkey()
            }
        })

        applySettings()
    }

    func stop() {
        guard isStarted else { return }
        isStarted = false
        pollTimer?.invalidate()
        pollTimer = nil
        pasteTask?.cancel()
        pasteTask = nil
        hotkeyManager.unregister()
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
        PasteboardOwnership.shared.willClaim = nil
        hide()
    }

    /// Pauses recording and the shortcut while Inklet imports or moves its data.
    func setSuspended(_ isSuspended: Bool) {
        guard self.isSuspended != isSuspended else { return }
        self.isSuspended = isSuspended
        if isSuspended {
            hide()
        }
        applySettings()
    }

    var isVisible: Bool {
        panel?.isVisible == true
    }

    @objc func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        guard isStarted, !isSuspended else { return }
        pollPasteboard()
        // Opened over Inklet itself (for example the writing popover), the paste goes to Inklet.
        let frontmost = NSWorkspace.shared.frontmostApplication
        targetApplication = frontmost?.processIdentifier == NSRunningApplication.current.processIdentifier
            ? nil
            : frontmost
        model.prepareForPresentation(
            isEnabled: ClipboardHistorySettings.isEnabled,
            canPaste: AXIsProcessTrusted()
        )
        let panel = self.panel ?? makePanel()
        self.panel = panel
        panel.appearance = (try? UserDefaultsConfigStore().load())?.appearance.nsAppearance
        position(panel)
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        guard let panel, panel.isVisible else { return }
        panel.orderOut(nil)
        model.didHide()
    }

    // MARK: Recording

    private func applySettings() {
        let shouldRecord = isStarted && !isSuspended && ClipboardHistorySettings.isEnabled
        if shouldRecord {
            if pollTimer == nil {
                lastChangeCount = pasteboard.changeCount
                let timer = Timer(timeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
                    MainActor.assumeIsolated {
                        self?.pollPasteboard()
                    }
                }
                timer.tolerance = 0.2
                RunLoop.main.add(timer, forMode: .common)
                pollTimer = timer
            }
            store.prune(retention: ClipboardHistorySettings.retention)
        } else {
            pollTimer?.invalidate()
            pollTimer = nil
        }
        registerHotkey()
        if isVisible {
            model.prepareForPresentation(
                isEnabled: ClipboardHistorySettings.isEnabled,
                canPaste: AXIsProcessTrusted()
            )
        }
    }

    private func pollPasteboard() {
        guard pollTimer != nil else { return }
        let changeCount = pasteboard.changeCount
        guard changeCount != lastChangeCount else { return }
        // Inklet is reading a selection or inserting text: wait for it to put the pasteboard back.
        guard !PasteboardOwnership.shared.isClaimed else { return }
        lastChangeCount = changeCount
        guard !PasteboardOwnership.shared.isIgnored(changeCount: changeCount),
              let capture = ClipboardPasteboard.capture(
                from: pasteboard,
                sourceApplication: NSWorkspace.shared.frontmostApplication
              )
        else {
            return
        }
        store.record(capture, retention: ClipboardHistorySettings.retention)
    }

    // MARK: Shortcut

    private func registerHotkey() {
        // A turned-off history doesn't keep its shortcut from other apps; the menu still opens it.
        guard isStarted, !isSuspended, !isRecordingHotkey, ClipboardHistorySettings.isEnabled else {
            hotkeyManager.unregister()
            return
        }
        do {
            let hotkey = try Hotkey.parse(ClipboardHistorySettings.hotkey)
            try hotkeyManager.register(hotkey) { [weak self] in
                Task { @MainActor in
                    self?.toggle()
                }
            }
        } catch {
            hotkeyManager.unregister()
            NSLog("Failed to register the clipboard history shortcut: \(String(describing: error))")
        }
    }

    // MARK: Paste and copy

    private func copy(_ item: ClipboardHistoryItem) {
        guard write(item) else { return }
        hide()
    }

    /// Puts an item back on the clipboard. Inklet records that copy itself, so the next poll
    /// doesn't credit it to the app in front.
    private func write(_ item: ClipboardHistoryItem) -> Bool {
        // Record a copy the person just made before it's replaced.
        pollPasteboard()
        guard ClipboardPasteboard.write(item, imageURL: store.imageURL(for: item), to: pasteboard) else {
            NSSound.beep()
            return false
        }
        lastChangeCount = pasteboard.changeCount
        store.touch(itemID: item.id)
        return true
    }

    /// Puts the item on the clipboard and pastes it into the app that was in front. Without
    /// Accessibility permission Inklet can't press ⌘V, so the item is only copied.
    private func paste(_ item: ClipboardHistoryItem) {
        guard write(item) else { return }
        let target = targetApplication
        hide()
        guard AXIsProcessTrusted() else { return }

        pasteTask?.cancel()
        pasteTask = Task { @MainActor in
            if let target, !target.isTerminated, !target.isActive {
                NSApplication.shared.yieldActivation(to: target)
                _ = target.activate()
                for _ in 0..<20 where !target.isActive {
                    try? await Task.sleep(for: .milliseconds(25))
                }
            }
            try? await Task.sleep(for: .milliseconds(40))
            guard !Task.isCancelled else { return }
            do {
                try InsertionService().sendPasteShortcut()
            } catch {
                NSLog("Clipboard history could not paste: \(String(describing: error))")
            }
        }
    }

    // MARK: Panel

    private func makePanel() -> ClipboardHistoryPanel {
        let panel = ClipboardHistoryPanel(
            contentRect: NSRect(origin: .zero, size: ClipboardHistoryView.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = false
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.onEscape = { [weak self] in self?.hide() }
        panel.onCommandKey = { [weak self] event in
            self?.handleCommandKey(event) ?? false
        }
        panel.contentView = ClipboardHistoryHostingView(rootView: ClipboardHistoryView(model: model))
        return panel
    }

    /// ⌘ shortcuts inside the panel. The search field keeps its own editing shortcuts, which are
    /// sent to it directly because the panel works while another app stays active.
    private func handleCommandKey(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers == .command, let panel else {
            return false
        }
        let editor = panel.firstResponder as? NSTextView
        let hasTextSelection = (editor?.selectedRange().length ?? 0) > 0

        if event.keyCode == 51 {
            // ⌘⌫ deletes the item; while there is a search it clears the search as usual.
            guard model.query.isEmpty else { return false }
            model.deleteSelected()
            return true
        }

        switch event.charactersIgnoringModifiers?.lowercased() {
        case "p":
            model.togglePinSelected()
            return true
        case "c":
            if hasTextSelection {
                return editor?.tryToPerform(#selector(NSText.copy(_:)), with: nil) ?? false
            }
            model.copySelected()
            return true
        case "v":
            return editor?.tryToPerform(#selector(NSText.paste(_:)), with: nil) ?? false
        case "x":
            return editor?.tryToPerform(#selector(NSText.cut(_:)), with: nil) ?? false
        case "a":
            return editor?.tryToPerform(#selector(NSText.selectAll(_:)), with: nil) ?? false
        case "w":
            hide()
            return true
        case ",":
            hide()
            onOpenSettings?()
            return true
        default:
            return false
        }
    }

    /// Centered on the screen with the pointer, a little above the middle, like Spotlight.
    private func position(_ panel: ClipboardHistoryPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let size = ClipboardHistoryView.size
        let origin = NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.minY + (visible.height - size.height) * 0.62
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }
}

@MainActor
final class ClipboardHistoryPanel: NSPanel {
    var onEscape: (() -> Void)?
    var onCommandKey: ((NSEvent) -> Bool)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if onCommandKey?(event) == true {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }
}

@MainActor
private final class ClipboardHistoryHostingView<Content: View>: NSHostingView<Content> {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureLayer()
    }

    override func layout() {
        super.layout()
        configureLayer()
    }

    private func configureLayer() {
        wantsLayer = true
        guard let layer else { return }
        layer.backgroundColor = NSColor.clear.cgColor
        layer.cornerRadius = InkletTheme.Radius.panel
        layer.cornerCurve = .continuous
        layer.masksToBounds = true
    }
}
