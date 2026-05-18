import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

public enum InsertionError: Error, Equatable {
    case accessibilityPermissionMissing
    case activationFailed
    case cannotCreatePasteEvent
    case clipboardRestoreFailed
}

@MainActor
public final class InsertionService {
    public typealias AccessibilityTrustProvider = @MainActor () -> Bool
    public typealias ApplicationActivator = @MainActor (NSRunningApplication) -> Bool
    public typealias PasteShortcutSender = @MainActor (CGEventSource?) throws -> Void
    public typealias DelayProvider = @MainActor (UInt64) async throws -> Void

    private let clipboardService: ClipboardService
    private let eventSource: CGEventSource?
    private let restoreDelayNanoseconds: UInt64
    private let activationDelayNanoseconds: UInt64
    private let accessibilityTrustProvider: AccessibilityTrustProvider
    private let applicationActivator: ApplicationActivator
    private let pasteShortcutSender: PasteShortcutSender
    private let delayProvider: DelayProvider

    public init(
        clipboardService: ClipboardService = ClipboardService(),
        eventSource: CGEventSource? = CGEventSource(stateID: .hidSystemState),
        restoreDelayNanoseconds: UInt64 = 1_000_000_000,
        activationDelayNanoseconds: UInt64 = 100_000_000,
        accessibilityTrustProvider: @escaping AccessibilityTrustProvider = { AXIsProcessTrusted() },
        applicationActivator: @escaping ApplicationActivator = InsertionService.activate,
        pasteShortcutSender: @escaping PasteShortcutSender = InsertionService.sendPasteShortcut,
        delayProvider: @escaping DelayProvider = { nanoseconds in
            try await Task.sleep(nanoseconds: nanoseconds)
        }
    ) {
        self.clipboardService = clipboardService
        self.eventSource = eventSource
        self.restoreDelayNanoseconds = restoreDelayNanoseconds
        self.activationDelayNanoseconds = activationDelayNanoseconds
        self.accessibilityTrustProvider = accessibilityTrustProvider
        self.applicationActivator = applicationActivator
        self.pasteShortcutSender = pasteShortcutSender
        self.delayProvider = delayProvider
    }

    public var isAccessibilityTrusted: Bool {
        accessibilityTrustProvider()
    }

    public func insert(text: String, into targetApplication: NSRunningApplication) async throws {
        guard isAccessibilityTrusted else {
            throw InsertionError.accessibilityPermissionMissing
        }

        let snapshot = clipboardService.save()
        clipboardService.writePlainText(text)

        do {
            guard applicationActivator(targetApplication) else {
                throw InsertionError.activationFailed
            }

            if activationDelayNanoseconds > 0 {
                try await delayProvider(activationDelayNanoseconds)
            }

            try sendPasteShortcut()

            if restoreDelayNanoseconds > 0 {
                try await delayProvider(restoreDelayNanoseconds)
            }
        } catch {
            guard clipboardService.restore(snapshot) else {
                NSLog("Failed to restore pasteboard after insertion error: \(error)")
                throw InsertionError.clipboardRestoreFailed
            }
            throw error
        }

        guard clipboardService.restore(snapshot) else {
            NSLog("Failed to restore pasteboard after insertion")
            throw InsertionError.clipboardRestoreFailed
        }
    }

    public func sendPasteShortcut() throws {
        try pasteShortcutSender(eventSource)
    }

    @usableFromInline
    static func activate(_ application: NSRunningApplication) -> Bool {
        if #available(macOS 14.0, *) {
            application.activate()
        } else {
            application.activate(options: [.activateIgnoringOtherApps])
        }
    }

    @usableFromInline
    static func sendPasteShortcut(eventSource: CGEventSource?) throws {
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
