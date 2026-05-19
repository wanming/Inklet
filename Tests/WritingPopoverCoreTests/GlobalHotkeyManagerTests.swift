import Carbon
import XCTest
@testable import WritingPopoverCore

@MainActor
final class GlobalHotkeyManagerTests: XCTestCase {
    func testParsesDefaultHotkey() throws {
        let hotkey = try Hotkey.parse("⌥Space")

        XCTAssertEqual(hotkey.keyCode, 49)
        XCTAssertEqual(hotkey.modifiers, [.option])
    }

    func testParsesFriendlyHotkeySpellings() throws {
        XCTAssertEqual(try Hotkey.parse("Option + Space"), Hotkey(keyCode: 49, modifiers: [.option]))
        XCTAssertEqual(try Hotkey.parse("Alt+Space"), Hotkey(keyCode: 49, modifiers: [.option]))
        XCTAssertEqual(try Hotkey.parse("Cmd + Space"), Hotkey(keyCode: 49, modifiers: [.command]))
    }

    func testParsesRecordedHotkeyDisplayStrings() throws {
        let hotkey = try Hotkey.parse("⌘⇧K")

        XCTAssertEqual(hotkey.keyCode, UInt32(kVK_ANSI_K))
        XCTAssertEqual(hotkey.modifiers, [.command, .shift])
        XCTAssertEqual(hotkey.displayString, "⇧⌘K")
    }

    func testRejectsUnsupportedHotkey() {
        XCTAssertThrowsError(try Hotkey.parse("Shift+Space")) { error in
            XCTAssertEqual(error as? HotkeyError, .unsupported("Shift+Space"))
        }
    }

    func testDefaultManagerIDsAreUnique() {
        let first = GlobalHotkeyManager()
        let second = GlobalHotkeyManager()

        XCTAssertNotEqual(first.registrationIdentity, second.registrationIdentity)

        let eventForFirst = EventHotKeyID(
            signature: first.registrationIdentity.signature,
            id: first.registrationIdentity.id
        )
        XCTAssertTrue(first.handles(eventForFirst))
        XCTAssertFalse(second.handles(eventForFirst))
    }

    func testHotkeyIdentityMatchesSignatureAndID() {
        let identity = HotkeyRegistrationIdentity(signature: 0x46554C54, id: 42)

        XCTAssertTrue(identity.matches(EventHotKeyID(signature: 0x46554C54, id: 42)))
        XCTAssertFalse(identity.matches(EventHotKeyID(signature: 0x46554C54, id: 43)))
        XCTAssertFalse(identity.matches(EventHotKeyID(signature: 0x4F544852, id: 42)))
    }
}
