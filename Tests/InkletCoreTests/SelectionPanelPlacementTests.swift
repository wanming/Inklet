import XCTest
@testable import InkletCore

final class SelectionPanelPlacementTests: XCTestCase {
    func testPrefersAboveAndRightOfAnchorWhenSpaceAllows() {
        let origin = SelectionPanelPlacement.origin(
            forPanelSize: SelectionPanelSize(width: 100, height: 50),
            near: SelectionPoint(x: 200, y: 200),
            in: SelectionScreenFrame(x: 0, y: 0, width: 500, height: 500)
        )

        XCTAssertEqual(origin, SelectionPoint(x: 212, y: 212))
    }

    func testUsesLeftSideWhenRightSideWouldLeaveVisibleFrame() {
        let origin = SelectionPanelPlacement.origin(
            forPanelSize: SelectionPanelSize(width: 100, height: 50),
            near: SelectionPoint(x: 470, y: 200),
            in: SelectionScreenFrame(x: 0, y: 0, width: 500, height: 500)
        )

        XCTAssertEqual(origin, SelectionPoint(x: 358, y: 212))
    }

    func testUsesBelowAnchorWhenAboveWouldLeaveVisibleFrame() {
        let origin = SelectionPanelPlacement.origin(
            forPanelSize: SelectionPanelSize(width: 100, height: 50),
            near: SelectionPoint(x: 200, y: 470),
            in: SelectionScreenFrame(x: 0, y: 0, width: 500, height: 500)
        )

        XCTAssertEqual(origin, SelectionPoint(x: 212, y: 408))
    }
}
