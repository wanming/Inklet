import XCTest
@testable import WritingPopoverCore

final class GlobalHotkeyManagerTests: XCTestCase {
    func testParsesDefaultHotkey() throws {
        let hotkey = try Hotkey.parse("⌥Space")

        XCTAssertEqual(hotkey.keyCode, 49)
        XCTAssertEqual(hotkey.modifiers, [.option])
    }

    func testRejectsUnsupportedHotkey() {
        XCTAssertThrowsError(try Hotkey.parse("Shift+Space")) { error in
            XCTAssertEqual(error as? HotkeyError, .unsupported("Shift+Space"))
        }
    }
}
