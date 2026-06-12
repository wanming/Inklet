import AppKit
import InkletCore

@MainActor
final class SelectionActionMonitor {
    var onCandidateSelection: ((SelectionPoint) -> Void)?
    var onDismiss: (() -> Void)?

    private var monitors: [Any] = []

    func start() {
        guard monitors.isEmpty else {
            return
        }

        monitors.append(NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp, .rightMouseUp]) { [weak self] _ in
            Task { @MainActor in
                self?.onCandidateSelection?(SelectionPoint(x: NSEvent.mouseLocation.x, y: NSEvent.mouseLocation.y))
            }
        } as Any)

        monitors.append(NSEvent.addGlobalMonitorForEvents(matching: [.keyUp]) { [weak self] event in
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard modifiers.contains(.shift) else {
                return
            }
            Task { @MainActor in
                self?.onCandidateSelection?(SelectionPoint(x: NSEvent.mouseLocation.x, y: NSEvent.mouseLocation.y))
            }
        } as Any)

        monitors.append(NSEvent.addGlobalMonitorForEvents(matching: [.scrollWheel, .keyDown, .leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                self?.onDismiss?()
            }
        } as Any)
    }

    func stop() {
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors.removeAll()
    }
}
