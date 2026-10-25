import AppKit
import XCTest
@testable import Inklet
@testable import InkletCore

@MainActor
final class CommandHoldMonitorTests: XCTestCase {
    private let leftCommand = NSEvent.ModifierFlags(rawValue: NSEvent.ModifierFlags.command.rawValue | 0x08)
    private let rightCommand = NSEvent.ModifierFlags(rawValue: NSEvent.ModifierFlags.command.rawValue | 0x10)

    func testOnlyCommandOnItsOwnRevealsShortcuts() {
        XCTAssertTrue(CommandHoldMonitor.isRevealingHold(leftCommand, ignoring: .rightOption))
        XCTAssertTrue(CommandHoldMonitor.isRevealingHold(.command, ignoring: .rightOption))
        XCTAssertFalse(CommandHoldMonitor.isRevealingHold([], ignoring: .rightOption))
        XCTAssertFalse(CommandHoldMonitor.isRevealingHold(leftCommand.union(.shift), ignoring: .rightOption))
        XCTAssertFalse(CommandHoldMonitor.isRevealingHold(.option, ignoring: .rightOption))
    }

    func testTheDictationCommandKeyNeverRevealsShortcuts() {
        XCTAssertFalse(CommandHoldMonitor.isRevealingHold(rightCommand, ignoring: .rightCommand))
        XCTAssertTrue(CommandHoldMonitor.isRevealingHold(leftCommand, ignoring: .rightCommand))
        XCTAssertFalse(CommandHoldMonitor.isRevealingHold(leftCommand, ignoring: .leftCommand))
        XCTAssertTrue(CommandHoldMonitor.isRevealingHold(rightCommand, ignoring: .leftCommand))
    }

    func testHoldRevealsAfterTheDelayAndReleaseHides() async throws {
        let monitor = CommandHoldMonitor()
        monitor.handle(type: .flagsChanged, modifierFlags: leftCommand)
        XCTAssertFalse(monitor.isRevealed)

        try await Task.sleep(for: CommandHoldMonitor.revealDelay + .milliseconds(150))
        XCTAssertTrue(monitor.isRevealed)

        monitor.handle(type: .flagsChanged, modifierFlags: [])
        XCTAssertFalse(monitor.isRevealed)
    }

    func testAShortcutBeforeTheDelayNeverReveals() async throws {
        let monitor = CommandHoldMonitor()
        monitor.handle(type: .flagsChanged, modifierFlags: leftCommand)
        monitor.handle(type: .keyDown, modifierFlags: leftCommand)

        try await Task.sleep(for: CommandHoldMonitor.revealDelay + .milliseconds(150))
        XCTAssertFalse(monitor.isRevealed)
    }

    func testTypingWhileRevealedHidesShortcuts() {
        let monitor = CommandHoldMonitor()
        monitor.reveal()
        monitor.handle(type: .keyDown, modifierFlags: leftCommand)
        XCTAssertFalse(monitor.isRevealed)
    }
}
