import XCTest
@testable import InkletCore

final class SelectionKeyboardPolicyTests: XCTestCase {
    func testCaretMovementKeysExtendSelection() {
        for keyCode: UInt16 in [123, 124, 125, 126, 115, 119, 116, 121] {
            XCTAssertTrue(SelectionKeyboardPolicy.isSelectionExtendingKey(keyCode: keyCode), "keyCode \(keyCode)")
        }
    }

    func testTypingKeysDoNotExtendSelection() {
        // a, s, 1, space, return, period, and the Shift key itself
        for keyCode: UInt16 in [0, 1, 18, 49, 36, 47, 56, 60] {
            XCTAssertFalse(SelectionKeyboardPolicy.isSelectionExtendingKey(keyCode: keyCode), "keyCode \(keyCode)")
        }
    }
}
