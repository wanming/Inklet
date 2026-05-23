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
    public typealias ApplicationActivityProvider = @MainActor (NSRunningApplication) -> Bool
    public typealias PasteShortcutSender = @MainActor (CGEventSource?) throws -> Void
    public typealias DelayProvider = @MainActor (UInt64) async throws -> Void
    public typealias RestoreDelayProvider = @MainActor (UInt64) async -> Void

    private let clipboardService: ClipboardService
    private let eventSource: CGEventSource?
    private let restoreDelayNanoseconds: UInt64
    private let activationDelayNanoseconds: UInt64
    private let activationTimeoutNanoseconds: UInt64
    private let accessibilityTrustProvider: AccessibilityTrustProvider
    private let applicationActivator: ApplicationActivator
    private let applicationActivityProvider: ApplicationActivityProvider
    private let pasteShortcutSender: PasteShortcutSender
    private let delayProvider: DelayProvider
    private let restoreDelayProvider: RestoreDelayProvider

    public init(
        clipboardService: ClipboardService = ClipboardService(),
        eventSource: CGEventSource? = CGEventSource(stateID: .hidSystemState),
        restoreDelayNanoseconds: UInt64 = 1_000_000_000,
        activationDelayNanoseconds: UInt64 = 50_000_000,
        activationTimeoutNanoseconds: UInt64 = 1_000_000_000,
        accessibilityTrustProvider: @escaping AccessibilityTrustProvider = { AXIsProcessTrusted() },
        applicationActivator: @escaping ApplicationActivator = InsertionService.activate,
        applicationActivityProvider: @escaping ApplicationActivityProvider = { $0.isActive },
        pasteShortcutSender: @escaping PasteShortcutSender = InsertionService.sendPasteShortcut,
        delayProvider: @escaping DelayProvider = { nanoseconds in
            try await Task.sleep(nanoseconds: nanoseconds)
        },
        restoreDelayProvider: @escaping RestoreDelayProvider = { nanoseconds in
            await InsertionService.nonCancellableSleep(nanoseconds: nanoseconds)
        }
    ) {
        self.clipboardService = clipboardService
        self.eventSource = eventSource
        self.restoreDelayNanoseconds = restoreDelayNanoseconds
        self.activationDelayNanoseconds = activationDelayNanoseconds
        self.activationTimeoutNanoseconds = activationTimeoutNanoseconds
        self.accessibilityTrustProvider = accessibilityTrustProvider
        self.applicationActivator = applicationActivator
        self.applicationActivityProvider = applicationActivityProvider
        self.pasteShortcutSender = pasteShortcutSender
        self.delayProvider = delayProvider
        self.restoreDelayProvider = restoreDelayProvider
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

            guard try await waitForActivation(of: targetApplication) else {
                throw InsertionError.activationFailed
            }

            try sendPasteShortcut()

            if restoreDelayNanoseconds > 0 {
                await restoreDelayProvider(restoreDelayNanoseconds)
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

        if Task.isCancelled {
            throw CancellationError()
        }
    }

    public func sendPasteShortcut() throws {
        try pasteShortcutSender(eventSource)
    }

    private func waitForActivation(of application: NSRunningApplication) async throws -> Bool {
        if applicationActivityProvider(application) {
            return true
        }

        var waitedNanoseconds: UInt64 = 0
        let delayNanoseconds = max(activationDelayNanoseconds, 1_000_000)

        while waitedNanoseconds < activationTimeoutNanoseconds {
            let remainingNanoseconds = activationTimeoutNanoseconds - waitedNanoseconds
            let nextDelayNanoseconds = min(delayNanoseconds, remainingNanoseconds)
            try await delayProvider(nextDelayNanoseconds)
            waitedNanoseconds += nextDelayNanoseconds

            if applicationActivityProvider(application) {
                return true
            }
        }

        return false
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

    @usableFromInline
    static func nonCancellableSleep(nanoseconds: UInt64) async {
        await withCheckedContinuation { continuation in
            let clampedNanoseconds = min(nanoseconds, UInt64(Int.max))
            DispatchQueue.main.asyncAfter(deadline: .now() + .nanoseconds(Int(clampedNanoseconds))) {
                continuation.resume()
            }
        }
    }
}
