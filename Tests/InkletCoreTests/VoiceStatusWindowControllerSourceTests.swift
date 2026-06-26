import XCTest

final class VoiceStatusWindowControllerSourceTests: XCTestCase {
    func testVoiceStatusWindowHidesBeforeSendingPasteShortcut() throws {
        let packageRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let sourceURL = packageRoot.appendingPathComponent("Sources/InkletApp/VoiceStatusWindowController.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        let insertingRange = try XCTUnwrap(source.range(of: "case .inserting:"))
        let fallbackRange = try XCTUnwrap(source.range(of: "case .fallbackInserted", range: insertingRange.upperBound..<source.endIndex))
        let insertingBlock = source[insertingRange.lowerBound..<fallbackRange.lowerBound]

        XCTAssertTrue(insertingBlock.contains("hideForTextInsertion()"))
        XCTAssertTrue(source.contains("private func hideForTextInsertion()"))
        XCTAssertTrue(source.contains("window?.orderOut(nil)"))
    }

    func testVoiceStatusWindowResetsWindowContentSizeAfterChooser() throws {
        let packageRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let sourceURL = packageRoot.appendingPathComponent("Sources/InkletApp/VoiceStatusWindowController.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        let resetRange = try XCTUnwrap(source.range(of: "private func resetSize"))
        let hideRange = try XCTUnwrap(source.range(of: "private func hideForTextInsertion", range: resetRange.upperBound..<source.endIndex))
        let resetBlock = source[resetRange.lowerBound..<hideRange.lowerBound]

        XCTAssertTrue(resetBlock.contains("window.setContentSize(Self.panelSize)"))
        XCTAssertFalse(resetBlock.contains("frame.size = Self.panelSize"))
    }

    func testVoiceStatusTextStartsNextToStatusDot() throws {
        let packageRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let sourceURL = packageRoot.appendingPathComponent("Sources/InkletApp/VoiceStatusWindowController.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        let statusViewRange = try XCTUnwrap(source.range(of: "private func makeStatusContentView"))
        let cancelRange = try XCTUnwrap(source.range(of: "@objc private func cancel", range: statusViewRange.upperBound..<source.endIndex))
        let statusViewBlock = source[statusViewRange.lowerBound..<cancelRange.lowerBound]

        XCTAssertTrue(statusViewBlock.contains("textField.alignment = .left"))
        XCTAssertTrue(statusViewBlock.contains("textField.setContentHuggingPriority(.required, for: .horizontal)"))
        XCTAssertTrue(statusViewBlock.contains("textField.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -6)"))
    }

    func testPromptModeSelectionKeyboardScrollDoesNotMoveHorizontally() throws {
        let packageRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let sourceURL = packageRoot.appendingPathComponent("Sources/InkletApp/VoiceStatusWindowController.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        let scrollRange = try XCTUnwrap(source.range(of: "private func scrollSelectedRowToVisible"))
        let endRange = try XCTUnwrap(source.range(of: "\n    }\n}", range: scrollRange.upperBound..<source.endIndex))
        let scrollBlock = source[scrollRange.lowerBound..<endRange.lowerBound]

        XCTAssertTrue(scrollBlock.contains("NSPoint(x: 0, y: targetY)"))
        XCTAssertTrue(scrollBlock.contains("clipView.scroll(to: targetOrigin)"))
        XCTAssertTrue(scrollBlock.contains("reflectScrolledClipView(clipView)"))
        XCTAssertFalse(scrollBlock.contains("scrollToVisible(rowRect(at: state.selectedIndex))"))
    }
}
