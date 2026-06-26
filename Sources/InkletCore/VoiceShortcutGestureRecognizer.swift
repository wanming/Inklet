import Foundation

public enum VoiceShortcutGestureAction: Equatable, Sendable {
    case start
    case stop
    case toggle
}

public struct VoiceShortcutGestureRecognizer: Equatable, Sendable {
    public var doubleTapInterval: TimeInterval

    private var isPressed = false
    private var isInterrupted = false
    private var didStartPressAndHold = false
    private var previousTapTime: TimeInterval?

    public init(doubleTapInterval: TimeInterval = 0.35) {
        self.doubleTapInterval = doubleTapInterval
    }

    public mutating func pressBegan(
        at time: TimeInterval,
        mode: VoiceInputConfig.RecordingMode
    ) -> [VoiceShortcutGestureAction] {
        guard !isPressed else {
            return []
        }

        isPressed = true
        isInterrupted = false
        didStartPressAndHold = false
        expireStaleTap(at: time)
        return []
    }

    public mutating func holdDelayElapsed(
        at time: TimeInterval,
        mode: VoiceInputConfig.RecordingMode
    ) -> [VoiceShortcutGestureAction] {
        expireStaleTap(at: time)
        guard mode == .pressAndHold, isPressed, !isInterrupted, !didStartPressAndHold else {
            return []
        }

        didStartPressAndHold = true
        previousTapTime = nil
        return [.start]
    }

    public mutating func pressEnded(
        at time: TimeInterval,
        mode: VoiceInputConfig.RecordingMode
    ) -> [VoiceShortcutGestureAction] {
        defer {
            isPressed = false
            isInterrupted = false
            didStartPressAndHold = false
        }

        guard isPressed, !isInterrupted else {
            return []
        }

        switch mode {
        case .tapToToggle:
            previousTapTime = nil
            return [.toggle]
        case .pressAndHold:
            previousTapTime = nil
            return didStartPressAndHold ? [.stop] : []
        case .doubleTap:
            if let previousTapTime, time - previousTapTime <= doubleTapInterval {
                self.previousTapTime = nil
                return [.toggle]
            }
            previousTapTime = time
            return []
        }
    }

    public mutating func interrupt() {
        guard isPressed else {
            previousTapTime = nil
            return
        }

        guard !didStartPressAndHold else {
            return
        }

        isInterrupted = true
        previousTapTime = nil
    }

    private mutating func expireStaleTap(at time: TimeInterval) {
        if let previousTapTime, time - previousTapTime > doubleTapInterval {
            self.previousTapTime = nil
        }
    }
}
