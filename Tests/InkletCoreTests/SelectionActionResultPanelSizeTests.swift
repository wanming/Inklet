import AppKit
import XCTest
@testable import Inklet
import InkletCore

@MainActor
final class SelectionActionResultPanelSizeTests: XCTestCase {
    func testShortTranslationOpensAsAShortPanelThatFitsOneLine() throws {
        try withoutRememberedPanelSize {
            let controller = SelectionActionWindowController()
            defer { controller.hidePanel() }
            controller.showMenu(at: SelectionPoint(x: 400, y: 400))
            controller.showTranslation("Z-Man Finesse TRD")

            let window = try XCTUnwrap(controller.window)
            XCTAssertEqual(window.frame.width, 320, accuracy: 1)
            // 12 pt top inset, one 14 pt line, 8 pt gap, hairline, 4 + 28 + 4 pt toolbar.
            XCTAssertGreaterThanOrEqual(window.frame.height, 72)
            XCTAssertLessThanOrEqual(window.frame.height, 90)
            XCTAssertEqual(window.minSize, NSSize(width: 300, height: 72))
            XCTAssertNil(UserDefaults.standard.object(forKey: InkletPreferenceKeys.translationPanelSize))
            try LocalizationSnapshot.record(try XCTUnwrap(window.contentView), name: "result-panel-short")
        }
    }

    func testLongerTranslationGrowsUntilItScrolls() throws {
        try withoutRememberedPanelSize {
            let controller = SelectionActionWindowController()
            defer { controller.hidePanel() }
            controller.showMenu(at: SelectionPoint(x: 400, y: 400))
            controller.showTranslation("Z-Man Finesse TRD")
            let window = try XCTUnwrap(controller.window)
            let oneLineHeight = window.frame.height

            controller.showTranslation(String(repeating: "A longer translation that wraps. ", count: 5))
            let paragraphHeight = window.frame.height
            try LocalizationSnapshot.record(try XCTUnwrap(window.contentView), name: "result-panel-paragraph")

            controller.showTranslation(String(repeating: "A much longer translation. ", count: 80))
            try LocalizationSnapshot.record(try XCTUnwrap(window.contentView), name: "result-panel-long")

            XCTAssertGreaterThan(paragraphHeight, oneLineHeight + 30)
            XCTAssertEqual(window.frame.height, 360, accuracy: 1)
        }
    }

    func testRememberedSizeKeepsItsWidthButStillFitsShortText() throws {
        try withRememberedPanelSize(["width": 480, "height": 400]) {
            let controller = SelectionActionWindowController()
            defer { controller.hidePanel() }
            controller.showMenu(at: SelectionPoint(x: 400, y: 400))
            controller.showTranslation("Z-Man Finesse TRD")

            let window = try XCTUnwrap(controller.window)
            XCTAssertEqual(window.frame.width, 480, accuracy: 1)
            XCTAssertLessThanOrEqual(window.frame.height, 90)
        }
    }

    func testResultFeedbackKeepsTheResultPanelSize() throws {
        try withoutRememberedPanelSize {
            let controller = SelectionActionWindowController()
            defer { controller.hidePanel() }
            controller.showMenu(at: SelectionPoint(x: 400, y: 400))
            controller.showTranslation("Z-Man Finesse TRD")
            let window = try XCTUnwrap(controller.window)
            let resultSize = window.frame.size

            controller.showTranslation("Z-Man Finesse TRD", feedback: .copiedTranslation)

            XCTAssertEqual(window.frame.size, resultSize)
        }
    }

    private func withoutRememberedPanelSize(_ body: () throws -> Void) rethrows {
        try withRememberedPanelSize(nil, body)
    }

    private func withRememberedPanelSize(_ size: [String: Double]?, _ body: () throws -> Void) rethrows {
        let key = InkletPreferenceKeys.translationPanelSize
        let previous = UserDefaults.standard.object(forKey: key)
        defer { UserDefaults.standard.set(previous, forKey: key) }
        UserDefaults.standard.set(size, forKey: key)
        try body()
    }
}
