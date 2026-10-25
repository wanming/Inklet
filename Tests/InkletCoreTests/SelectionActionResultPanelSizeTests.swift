import AppKit
import XCTest
@testable import Inklet
import InkletCore

@MainActor
final class SelectionActionResultPanelSizeTests: XCTestCase {
    func testShortTranslationOpensAtTheMinimumResultPanelSize() throws {
        try withoutRememberedPanelSize {
            let controller = SelectionActionWindowController()
            defer { controller.hidePanel() }
            controller.showMenu(at: SelectionPoint(x: 400, y: 400))
            controller.showTranslation("Z-Man Finesse TRD")

            let window = try XCTUnwrap(controller.window)
            XCTAssertGreaterThanOrEqual(window.frame.width, 300)
            XCTAssertGreaterThanOrEqual(window.frame.height, 180)
            XCTAssertEqual(window.minSize, NSSize(width: 300, height: 180))
            XCTAssertNil(UserDefaults.standard.object(forKey: InkletPreferenceKeys.translationPanelSize))
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
        let key = InkletPreferenceKeys.translationPanelSize
        let previous = UserDefaults.standard.object(forKey: key)
        defer { UserDefaults.standard.set(previous, forKey: key) }
        UserDefaults.standard.removeObject(forKey: key)
        try body()
    }
}
