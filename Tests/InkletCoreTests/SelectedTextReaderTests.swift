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

    func testFallsBackToSourceApplicationFocusedElementWhenSystemFocusedElementIsMissing() {
        let requestedProcessIdentifier = TestBox<pid_t>()
        let reader = SelectedTextReader(
            isTrusted: { true },
            focusedElementProvider: { nil },
            applicationFocusedElementProvider: { processIdentifier in
                requestedProcessIdentifier.value = processIdentifier
                return SelectedTextElement(rawValue: "app-field")
            },
            elementAtPositionProvider: { _ in nil },
            selectedTextProvider: { element in
                element.rawValue == AnyHashable("app-field") ? .success("hello") : .success("")
            }
        )

        XCTAssertEqual(reader.readSelectedText(sourceProcessIdentifier: 42), .success("hello"))
        XCTAssertEqual(requestedProcessIdentifier.value, 42)
    }

    func testFallsBackToElementAtMouseLocationWhenFocusedElementsAreMissing() {
        let selectionPoint = SelectionPoint(x: 24, y: 48)
        let requestedPoint = TestBox<SelectionPoint>()
        let reader = SelectedTextReader(
            isTrusted: { true },
            focusedElementProvider: { nil },
            applicationFocusedElementProvider: { _ in nil },
            elementAtPositionProvider: { point in
                requestedPoint.value = point
                return SelectedTextElement(rawValue: "hit-field")
            },
            selectedTextProvider: { element in
                element.rawValue == AnyHashable("hit-field") ? .success("hello") : .success("")
            }
        )

        XCTAssertEqual(reader.readSelectedText(mouseLocation: selectionPoint), .success("hello"))
        XCTAssertEqual(requestedPoint.value, selectionPoint)
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

private final class TestBox<Value>: @unchecked Sendable {
    var value: Value?
}
