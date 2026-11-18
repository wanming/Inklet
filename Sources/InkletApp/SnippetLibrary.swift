import AppKit
import ApplicationServices
import Carbon
import Combine
import InkletCore

extension Notification.Name {
    /// Posted by Settings after the keyword expansion switch changes.
    static let inkletSnippetSettingsDidChange = Notification.Name("InkletSnippetSettingsDidChange")
    /// Posted after a snippet is added, edited or deleted.
    static let inkletSnippetsDidChange = Notification.Name("InkletSnippetsDidChange")
}

/// The snippets shared by the ⌥⇧V panel, Settings › Snippets and keyword expansion.
@MainActor
final class SnippetLibrary: ObservableObject {
    static let shared = SnippetLibrary(
        store: SnippetStore(fileURL: InkletStoragePaths.currentOrLocalDevelopment().snippetsFileURL)
    )

    @Published private(set) var snippets: [Snippet] = []
    let store: SnippetStore

    init(store: SnippetStore) {
        self.store = store
        store.onChange = { [weak self] in
            self?.snippets = self?.store.snippets ?? []
            NotificationCenter.default.post(name: .inkletSnippetsDidChange, object: nil)
        }
        store.load()
        snippets = store.snippets
    }

    static var expandsKeywords: Bool {
        UserDefaults.standard.object(forKey: InkletPreferenceKeys.snippetKeywordExpansionEnabled) as? Bool
            ?? SnippetDefaults.expandsKeywords
    }

    @discardableResult
    func add() -> Snippet {
        store.add()
    }

    func update(_ snippet: Snippet) {
        store.update(snippet)
    }

    func delete(id: UUID) {
        store.delete(id: id)
    }

    func snippet(id: UUID?) -> Snippet? {
        id.flatMap(store.snippet(id:))
    }

    func keywordIssue(_ keyword: String, for snippetID: UUID) -> SnippetKeywordIssue? {
        store.keywordIssue(keyword, for: snippetID)
    }
}

/// Replaces a snippet's keyword with its text as the person types it in any app. It reads key
/// presses with a global monitor, which needs Accessibility, and never sees password fields
/// (macOS hides secure input from monitors). While an input method such as Pinyin is in use it
/// stays quiet, since the keys typed there are not the text that ends up in the document.
@MainActor
final class SnippetKeywordExpander {
    private static let deleteKeyCode: UInt16 = 51
    /// Keys that move the caret or leave the text: Return, Tab, Esc, Enter, Home, Page Up,
    /// Forward Delete, End, Page Down and the arrows.
    private static let resettingKeyCodes: Set<UInt16> = [36, 48, 53, 76, 115, 116, 117, 119, 121, 123, 124, 125, 126]

    private let library: SnippetLibrary
    private var monitor: Any?
    private var buffer = SnippetTypingBuffer()
    private var isActive = false
    private var expansionTask: Task<Void, Never>?

    init(library: SnippetLibrary) {
        self.library = library
    }

    /// Runs only while Inklet is running normally, the switch is on and Accessibility is granted.
    func setActive(_ isActive: Bool) {
        self.isActive = isActive
        refresh()
    }

    func refresh() {
        let shouldRun = isActive && SnippetLibrary.expandsKeywords && AXIsProcessTrusted()
        if shouldRun, monitor == nil {
            monitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]
            ) { [weak self] event in
                MainActor.assumeIsolated {
                    self?.handle(event)
                }
            }
        } else if !shouldRun {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
            buffer.handle(.reset)
            expansionTask?.cancel()
            expansionTask = nil
        }
    }

    private func handle(_ event: NSEvent) {
        guard expansionTask == nil else { return }
        guard event.type == .keyDown else {
            buffer.handle(.reset)
            return
        }
        let modifiers = event.modifierFlags.intersection([.command, .control])
        if !modifiers.isEmpty || Self.resettingKeyCodes.contains(event.keyCode) {
            buffer.handle(.reset)
            return
        }
        if event.keyCode == Self.deleteKeyCode {
            buffer.handle(.deleteBackward)
            return
        }
        if Self.isUsingInputMethod {
            buffer.handle(.reset)
            return
        }
        buffer.handle(.characters(event.characters ?? ""))
        guard let snippet = library.store.snippet(endingTypedText: buffer.text) else {
            return
        }
        buffer.handle(.reset)
        expand(snippet)
    }

    private func expand(_ snippet: Snippet) {
        expansionTask = Task { @MainActor [weak self] in
            // Let the app finish typing the keyword's last character first.
            try? await Task.sleep(for: .milliseconds(40))
            guard !Task.isCancelled else {
                self?.expansionTask = nil
                return
            }
            Self.postDeleteBackward(count: snippet.keyword.count)
            try? await Task.sleep(for: .milliseconds(40))
            await Self.pasteKeepingClipboard(snippet.text)
            self?.expansionTask = nil
        }
    }

    private static func postDeleteBackward(count: Int) {
        let source = CGEventSource(stateID: .hidSystemState)
        for _ in 0..<count {
            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(deleteKeyCode), keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(deleteKeyCode), keyDown: false)
            else {
                return
            }
            keyDown.flags = []
            keyUp.flags = []
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
        }
    }

    /// Pastes the text through the clipboard, then puts back what was there, so expanding a
    /// keyword doesn't change the clipboard or add to clipboard history.
    private static func pasteKeepingClipboard(_ text: String) async {
        let clipboard = ClipboardService()
        let claim = PasteboardOwnership.shared.claim(clipboard.pasteboard)
        let snapshot = clipboard.save()
        clipboard.writePlainText(text)
        do {
            try InsertionService().sendPasteShortcut()
        } catch {
            NSLog("Snippet expansion could not paste: \(String(describing: error))")
        }
        // The app reads the clipboard when it handles ⌘V; give it time before restoring.
        try? await Task.sleep(for: .milliseconds(500))
        clipboard.restore(snapshot)
        PasteboardOwnership.shared.release(claim, ignoringThrough: clipboard.pasteboard.changeCount)
    }

    /// Input methods (Pinyin, Kana, Hangul…) compose text from the keys, so keywords are only
    /// matched with a plain keyboard layout.
    private static var isUsingInputMethod: Bool {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(source, kTISPropertyInputSourceType)
        else {
            return false
        }
        let type = Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue()
        return CFEqual(type, kTISTypeKeyboardInputMode)
    }
}
