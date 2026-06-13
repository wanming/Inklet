import XCTest
@testable import InkletCore

final class SelectionDragPolicyTests: XCTestCase {
    func testClickWithoutDragDoesNotTriggerCandidate() {
        var policy = SelectionDragPolicy(minimumDistance: 6)
        policy.recordMouseDown(at: SelectionPoint(x: 10, y: 10))

        XCTAssertFalse(policy.consumeMouseUp(at: SelectionPoint(x: 12, y: 12)))
    }

    func testDragPastThresholdTriggersCandidate() {
        var policy = SelectionDragPolicy(minimumDistance: 6)
        policy.recordMouseDown(at: SelectionPoint(x: 10, y: 10))

        XCTAssertTrue(policy.consumeMouseUp(at: SelectionPoint(x: 20, y: 10)))
    }

    func testMouseUpWithoutMouseDownDoesNotTriggerCandidate() {
        var policy = SelectionDragPolicy(minimumDistance: 6)

        XCTAssertFalse(policy.consumeMouseUp(at: SelectionPoint(x: 20, y: 10)))
    }
}
