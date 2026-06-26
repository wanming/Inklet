import AppKit
import InkletCore

final class VoiceShortcutMonitor {
    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?
    private var shortcut: VoiceInputConfig.Shortcut = .disabled
    private var recordingMode: VoiceInputConfig.RecordingMode = .tapToToggle
    private var modifierPressTracker = VoiceShortcutModifierPressTracker()
    private var gestureRecognizer = VoiceShortcutGestureRecognizer()
    private var onToggle: (() -> Void)?
    private var onStart: (() -> Void)?
    private var onStop: (() -> Void)?
    private var onCancel: (() -> Void)?
    private var isVoiceInputActive = false
    private var candidateKeyCode: UInt16?
    private var holdStartWorkItem: DispatchWorkItem?
    private let holdActivationDelay: TimeInterval = 0.08

    func update(
        shortcut: VoiceInputConfig.Shortcut,
        recordingMode: VoiceInputConfig.RecordingMode,
        onToggle: @escaping () -> Void,
        onStart: @escaping () -> Void,
        onStop: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        stop()
        self.shortcut = shortcut
        self.recordingMode = recordingMode
        self.onToggle = onToggle
        self.onStart = onStart
        self.onStop = onStop
        self.onCancel = onCancel
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
        cancelPendingHoldStart()
        modifierPressTracker.reset()
        gestureRecognizer = VoiceShortcutGestureRecognizer()
        onToggle = nil
        onStart = nil
        onStop = nil
        onCancel = nil
        isVoiceInputActive = false
    }

    func setVoiceInputActive(_ isActive: Bool) {
        isVoiceInputActive = isActive
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
        case .keyDown:
            monitor.handleKeyDown(keyCode: keyCode)
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            monitor.markGestureInterrupted()
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let eventTap = monitor.eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
        default:
            break
        }
        return Unmanaged.passUnretained(event)
    }

    private func handleKeyDown(keyCode: UInt16) {
        markGestureInterrupted()
        guard VoiceInputCancellationPolicy.shouldCancel(
            keyCode: keyCode,
            isVoiceInputActive: isVoiceInputActive
        ) else {
            return
        }

        isVoiceInputActive = false
        onCancel?()
    }

    private func handleFlagsChanged(keyCode: UInt16, flags: CGEventFlags) {
        guard let expectedKeyCode = shortcut.keyCode,
              keyCode == expectedKeyCode
        else {
            return
        }

        switch modifierPressTracker.transition(
            keyCode: keyCode,
            expectedKeyCode: expectedKeyCode,
            isConfiguredModifierDown: isConfiguredModifierDown(in: flags)
        ) {
        case .began:
            handle(gestureRecognizer.pressBegan(at: currentTime, mode: recordingMode))
            if recordingMode == .pressAndHold {
                scheduleHoldStart(for: keyCode)
            }
        case .ended:
            cancelPendingHoldStart()
            handle(gestureRecognizer.pressEnded(at: currentTime, mode: recordingMode))
        case .ignored:
            break
        }
    }

    private func markGestureInterrupted() {
        gestureRecognizer.interrupt()
        if candidateKeyCode != nil {
            cancelPendingHoldStart()
        }
    }

    private func scheduleHoldStart(for keyCode: UInt16) {
        guard candidateKeyCode == nil else {
            return
        }

        cancelPendingHoldStart()
        candidateKeyCode = keyCode
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.candidateKeyCode == keyCode else {
                return
            }

            self.candidateKeyCode = nil
            self.holdStartWorkItem = nil
            self.handle(self.gestureRecognizer.holdDelayElapsed(at: self.currentTime, mode: self.recordingMode))
        }
        holdStartWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + holdActivationDelay, execute: workItem)
    }

    private func cancelPendingHoldStart() {
        holdStartWorkItem?.cancel()
        holdStartWorkItem = nil
        candidateKeyCode = nil
    }

    private func handle(_ actions: [VoiceShortcutGestureAction]) {
        for action in actions {
            switch action {
            case .start:
                onStart?()
            case .stop:
                onStop?()
            case .toggle:
                onToggle?()
            }
        }
    }

    private var currentTime: TimeInterval {
        ProcessInfo.processInfo.systemUptime
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
