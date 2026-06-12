import XCTest
@testable import InkletCore

final class SelectedTextReaderTests: XCTestCase {
    func testPermissionDeniedWhenNotTrusted() {
        let reader = SelectedTextReader(
            isTrusted: { false },
            focusedElementProvider: { nil },
            selectedTextProvider: { _ in .success("ignored") }
        )

        XCTAssertEqual(reader.readSelectedText(), .permissionDenied)
    }

    func testMissingFocusedElement() {
        let reader = SelectedTextReader(
            isTrusted: { true },
            focusedElementProvider: { nil },
            selectedTextProvider: { _ in .success("ignored") }
        )

        XCTAssertEqual(reader.readSelectedText(), .missingFocusedElement)
    }

    func testEmptySelection() {
        let reader = SelectedTextReader(
            isTrusted: { true },
            focusedElementProvider: { SelectedTextElement(rawValue: "field") },
            selectedTextProvider: { _ in .success(" \n\t ") }
        )

        XCTAssertEqual(reader.readSelectedText(), .emptySelection)
    }

    func testSuccessfulSelectionTrimsOuterWhitespaceAndPreservesLineBreaks() {
        let reader = SelectedTextReader(
            isTrusted: { true },
            focusedElementProvider: { SelectedTextElement(rawValue: "field") },
            selectedTextProvider: { _ in .success("  hello\nworld  ") }
        )

        XCTAssertEqual(reader.readSelectedText(), .success("hello\nworld"))
    }

    func testUnsupportedAttribute() {
        let reader = SelectedTextReader(
            isTrusted: { true },
            focusedElementProvider: { SelectedTextElement(rawValue: "field") },
            selectedTextProvider: { _ in .failure(.unsupported) }
        )

        XCTAssertEqual(reader.readSelectedText(), .unsupported)
    }
}
