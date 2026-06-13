import AppKit
import InkletCore

@MainActor
final class SelectionActionMonitor {
    var onCandidateSelection: ((SelectionPoint) -> Void)?
    var onCopyTrigger: ((SelectionPoint) -> Void)?
    var onDismiss: (() -> Void)?

    private var monitors: [Any] = []
    private var dismissalPolicy = SelectionDismissalPolicy()
    private var copyTriggerPolicy = SelectionCopyTriggerPolicy()
    private var dragPolicy = SelectionDragPolicy()

    func start() {
        guard monitors.isEmpty else {
            return
        }

        SelectionActionDiagnostics.log("starting global monitors")
        monitors.append(NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp, .rightMouseUp]) { [weak self] event in
            Task { @MainActor in
                guard let self else { return }
                let point = SelectionPoint(x: NSEvent.mouseLocation.x, y: NSEvent.mouseLocation.y)
                guard event.type != .leftMouseUp || self.dragPolicy.consumeMouseUp(at: point) else {
                    return
                }

                SelectionActionDiagnostics.log("candidate mouse selection")
                self.dismissalPolicy.recordCandidate(at: Date().timeIntervalSinceReferenceDate)
                self.onCandidateSelection?(point)
            }
        } as Any)

        monitors.append(NSEvent.addGlobalMonitorForEvents(matching: [.keyUp]) { [weak self] event in
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard modifiers.contains(.shift) else {
                return
            }
            Task { @MainActor in
                SelectionActionDiagnostics.log("candidate keyboard selection")
                self?.dismissalPolicy.recordCandidate(at: Date().timeIntervalSinceReferenceDate)
                self?.onCandidateSelection?(SelectionPoint(x: NSEvent.mouseLocation.x, y: NSEvent.mouseLocation.y))
            }
        } as Any)

        monitors.append(NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            Task { @MainActor in
                guard let self else { return }
                if self.isCopyShortcut(event),
                   self.copyTriggerPolicy.recordCopy(at: Date().timeIntervalSinceReferenceDate) {
                    SelectionActionDiagnostics.log("copy trigger")
                    self.onCopyTrigger?(SelectionPoint(x: NSEvent.mouseLocation.x, y: NSEvent.mouseLocation.y))
                    return
                }

                guard self.dismissalPolicy.shouldDismiss(at: Date().timeIntervalSinceReferenceDate) else {
                    SelectionActionDiagnostics.log("dismiss suppressed during selection grace")
                    return
                }
                self.onDismiss?()
            }
        } as Any)

        monitors.append(NSEvent.addGlobalMonitorForEvents(matching: [.scrollWheel, .leftMouseDown, .rightMouseDown]) { [weak self] event in
            Task { @MainActor in
                guard let self else { return }
                if event.type == .leftMouseDown {
                    self.dragPolicy.recordMouseDown(at: SelectionPoint(x: NSEvent.mouseLocation.x, y: NSEvent.mouseLocation.y))
                }
                guard self.dismissalPolicy.shouldDismiss(at: Date().timeIntervalSinceReferenceDate) else {
                    SelectionActionDiagnostics.log("dismiss suppressed during selection grace")
                    return
                }
                self.onDismiss?()
            }
        } as Any)
    }

    func stop() {
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors.removeAll()
    }

    private func isCopyShortcut(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return event.keyCode == 8 && modifiers == .command
    }
}
