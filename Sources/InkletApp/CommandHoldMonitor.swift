import AppKit
import Combine
import InkletCore

/// Reports when ⌘ is held on its own for a moment, so the writing popover can reveal every shortcut.
/// Any other key or modifier hides them again, so ⌘ combinations such as ⌘↵ never flash the strip.
/// The Command key used as the dictation shortcut is ignored; holding it dictates instead.
@MainActor
final class CommandHoldMonitor: ObservableObject {
    @Published private(set) var isRevealed = false

    static let revealDelay: Duration = .milliseconds(450)

    /// The dictation shortcut, read on every key change so a settings change applies at once.
    var dictationShortcut: @MainActor () -> VoiceInputConfig.Shortcut = { .disabled }

    private var monitor: Any?
    private var revealTask: Task<Void, Never>?

    func start() {
        guard monitor == nil else {
            return
        }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            self?.handle(type: event.type, modifierFlags: event.modifierFlags)
            return event
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        reset()
    }

    func handle(type: NSEvent.EventType, modifierFlags: NSEvent.ModifierFlags) {
        guard type == .flagsChanged, Self.isRevealingHold(modifierFlags, ignoring: dictationShortcut()) else {
            reset()
            return
        }
        guard revealTask == nil, !isRevealed else {
            return
        }
        revealTask = Task { [weak self] in
            try? await Task.sleep(for: Self.revealDelay)
            guard !Task.isCancelled else {
                return
            }
            self?.isRevealed = true
            self?.revealTask = nil
        }
    }

    /// Shows every shortcut at once, as a held ⌘ does after the delay.
    func reveal() {
        revealTask?.cancel()
        revealTask = nil
        isRevealed = true
    }

    private func reset() {
        revealTask?.cancel()
        revealTask = nil
        if isRevealed {
            isRevealed = false
        }
    }

    // Device-dependent bits for the left and right Command keys (NX_DEVICELCMDKEYMASK, NX_DEVICERCMDKEYMASK).
    private nonisolated static let leftCommandBit: UInt = 0x08
    private nonisolated static let rightCommandBit: UInt = 0x10

    /// Only ⌘ is down, and not just the Command key that starts dictation.
    nonisolated static func isRevealingHold(
        _ flags: NSEvent.ModifierFlags,
        ignoring dictationShortcut: VoiceInputConfig.Shortcut
    ) -> Bool {
        guard flags.intersection(.deviceIndependentFlagsMask) == .command else {
            return false
        }
        var left = flags.rawValue & leftCommandBit != 0
        var right = flags.rawValue & rightCommandBit != 0
        if !left && !right {
            // Synthesized events may carry no device bits; treat them as either key.
            left = true
            right = true
        }
        switch dictationShortcut {
        case .leftCommand:
            left = false
        case .rightCommand:
            right = false
        case .rightOption, .leftOption, .disabled:
            break
        }
        return left || right
    }
}
