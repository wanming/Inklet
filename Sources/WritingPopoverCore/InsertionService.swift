import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

public enum InsertionError: Error, Equatable {
    case accessibilityPermissionMissing
    case cannotCreatePasteEvent
}

@MainActor
public final class InsertionService {
    private let clipboardService: ClipboardService
    private let eventSource: CGEventSource?

    public init(
        clipboardService: ClipboardService = ClipboardService(),
        eventSource: CGEventSource? = CGEventSource(stateID: .hidSystemState)
    ) {
        self.clipboardService = clipboardService
        self.eventSource = eventSource
    }

    public var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    public func insert(text: String, into targetApplication: NSRunningApplication) async throws {
        guard isAccessibilityTrusted else {
            throw InsertionError.accessibilityPermissionMissing
        }

        let snapshot = clipboardService.save()
        clipboardService.writePlainText(text)
        defer {
            clipboardService.restore(snapshot)
        }

        if #available(macOS 14.0, *) {
            targetApplication.activate()
        } else {
            targetApplication.activate(options: [.activateIgnoringOtherApps])
        }
        try sendPasteShortcut()
        try await Task.sleep(nanoseconds: 300_000_000)
    }

    public func sendPasteShortcut() throws {
        guard let eventSource,
              let keyDown = CGEvent(
                keyboardEventSource: eventSource,
                virtualKey: 0x09,
                keyDown: true
              ),
              let keyUp = CGEvent(
                keyboardEventSource: eventSource,
                virtualKey: 0x09,
                keyDown: false
              )
        else {
            throw InsertionError.cannotCreatePasteEvent
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
