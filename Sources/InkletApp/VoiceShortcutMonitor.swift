import AppKit
import InkletCore

@MainActor
final class VoiceShortcutMonitor {
    private var globalFlagsMonitor: Any?
    private var globalKeyMonitor: Any?
    private var localFlagsMonitor: Any?
    private var localKeyMonitor: Any?
    private var shortcut: VoiceInputConfig.Shortcut = .disabled
    private var onTrigger: (() -> Void)?
    private var candidateKeyCode: UInt16?
    private var candidateSawOtherKey = false

    func update(shortcut: VoiceInputConfig.Shortcut, onTrigger: @escaping () -> Void) {
        stop()
        self.shortcut = shortcut
        self.onTrigger = onTrigger
        guard shortcut != .disabled else {
            return
        }

        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in self?.handleFlagsChanged(event) }
        }
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.markCandidateInterrupted() }
        }
        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in self?.handleFlagsChanged(event) }
            return event
        }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            Task { @MainActor in self?.markCandidateInterrupted() }
            return event
        }
    }

    func stop() {
        for monitor in [globalFlagsMonitor, globalKeyMonitor, localFlagsMonitor, localKeyMonitor].compactMap({ $0 }) {
            NSEvent.removeMonitor(monitor)
        }
        globalFlagsMonitor = nil
        globalKeyMonitor = nil
        localFlagsMonitor = nil
        localKeyMonitor = nil
        candidateKeyCode = nil
        candidateSawOtherKey = false
        onTrigger = nil
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        guard let expectedKeyCode = shortcut.keyCode,
              event.keyCode == expectedKeyCode
        else {
            if candidateKeyCode != nil {
                candidateSawOtherKey = true
            }
            return
        }

        if isConfiguredModifierDown(in: event.modifierFlags) {
            candidateKeyCode = event.keyCode
            candidateSawOtherKey = false
            return
        }

        guard candidateKeyCode == event.keyCode, !candidateSawOtherKey else {
            candidateKeyCode = nil
            candidateSawOtherKey = false
            return
        }

        candidateKeyCode = nil
        candidateSawOtherKey = false
        onTrigger?()
    }

    private func markCandidateInterrupted() {
        if candidateKeyCode != nil {
            candidateSawOtherKey = true
        }
    }

    private func isConfiguredModifierDown(in flags: NSEvent.ModifierFlags) -> Bool {
        let deviceIndependentFlags = flags.intersection(.deviceIndependentFlagsMask)
        switch shortcut {
        case .rightOption, .leftOption:
            return deviceIndependentFlags.contains(.option)
        case .rightCommand, .leftCommand:
            return deviceIndependentFlags.contains(.command)
        case .disabled:
            return false
        }
    }
}

private extension VoiceInputConfig.Shortcut {
    var keyCode: UInt16? {
        switch self {
        case .rightOption:
            return 61
        case .rightCommand:
            return 54
        case .leftOption:
            return 58
        case .leftCommand:
            return 55
        case .disabled:
            return nil
        }
    }
}
