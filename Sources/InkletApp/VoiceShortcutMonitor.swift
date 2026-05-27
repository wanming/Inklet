import AppKit
import InkletCore

final class VoiceShortcutMonitor {
    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?
    private var shortcut: VoiceInputConfig.Shortcut = .disabled
    private var onTrigger: (() -> Void)?
    private var candidateKeyCode: UInt16?
    private var triggerWorkItem: DispatchWorkItem?
    private let triggerDelay: TimeInterval = 0.08

    func update(shortcut: VoiceInputConfig.Shortcut, onTrigger: @escaping () -> Void) {
        stop()
        self.shortcut = shortcut
        self.onTrigger = onTrigger
        guard shortcut != .disabled else {
            return
        }

        let eventMask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
            | CGEventMask(1 << CGEventType.keyDown.rawValue)
            | CGEventMask(1 << CGEventType.leftMouseDown.rawValue)
            | CGEventMask(1 << CGEventType.rightMouseDown.rawValue)
            | CGEventMask(1 << CGEventType.otherMouseDown.rawValue)
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: VoiceShortcutMonitor.eventTapCallback,
            userInfo: userInfo
        ) else {
            NSLog("Failed to install voice shortcut event tap.")
            return
        }

        eventTap = tap
        eventTapSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let eventTapSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), eventTapSource, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let eventTapSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), eventTapSource, .commonModes)
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
        eventTapSource = nil
        eventTap = nil
        candidateKeyCode = nil
        cancelPendingTrigger()
        onTrigger = nil
    }

    private nonisolated static let eventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else {
            return Unmanaged.passUnretained(event)
        }

        let monitor = Unmanaged<VoiceShortcutMonitor>.fromOpaque(userInfo).takeUnretainedValue()
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        switch type {
        case .flagsChanged:
            monitor.handleFlagsChanged(keyCode: keyCode, flags: flags)
        case .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown:
            monitor.markCandidateInterrupted()
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let eventTap = monitor.eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
        default:
            break
        }
        return Unmanaged.passUnretained(event)
    }

    private func handleFlagsChanged(keyCode: UInt16, flags: CGEventFlags) {
        guard let expectedKeyCode = shortcut.keyCode,
              keyCode == expectedKeyCode
        else {
            return
        }

        if isConfiguredModifierDown(in: flags) {
            scheduleTrigger(for: keyCode)
            return
        }

        candidateKeyCode = nil
    }

    private func markCandidateInterrupted() {
        if candidateKeyCode != nil {
            cancelPendingTrigger()
        }
    }

    private func scheduleTrigger(for keyCode: UInt16) {
        guard candidateKeyCode == nil else {
            return
        }

        cancelPendingTrigger()
        candidateKeyCode = keyCode
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.candidateKeyCode == keyCode else {
                return
            }

            self.candidateKeyCode = nil
            self.triggerWorkItem = nil
            self.onTrigger?()
        }
        triggerWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + triggerDelay, execute: workItem)
    }

    private func cancelPendingTrigger() {
        triggerWorkItem?.cancel()
        triggerWorkItem = nil
        candidateKeyCode = nil
    }

    private func isConfiguredModifierDown(in flags: CGEventFlags) -> Bool {
        switch shortcut {
        case .rightOption, .leftOption:
            return flags.contains(.maskAlternate)
        case .rightCommand, .leftCommand:
            return flags.contains(.maskCommand)
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
