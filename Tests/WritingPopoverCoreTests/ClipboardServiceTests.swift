import AppKit
import XCTest
@testable import WritingPopoverCore

final class ClipboardServiceTests: XCTestCase {
    @MainActor
    func testWritesAndRestoresPlainText() {
        let pasteboard = NSPasteboard.withUniqueName()
        let service = ClipboardService(pasteboard: pasteboard)
        let original = "Original clipboard text"
        let generated = "Generated replacement text"

        pasteboard.clearContents()
        pasteboard.setString(original, forType: .string)

        let snapshot = service.save()
        service.writePlainText(generated)

        XCTAssertEqual(pasteboard.string(forType: .string), generated)

        service.restore(snapshot)

        XCTAssertEqual(pasteboard.string(forType: .string), original)
    }
}
