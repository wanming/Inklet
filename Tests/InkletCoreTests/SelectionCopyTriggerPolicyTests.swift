import XCTest
@testable import InkletCore

final class SelectionCopyTriggerPolicyTests: XCTestCase {
    func testFirstCopyDoesNotTrigger() {
        var policy = SelectionCopyTriggerPolicy(doubleCopyInterval: 0.8)

        XCTAssertFalse(policy.recordCopy(at: 10))
    }

    func testSecondCopyInsideIntervalTriggers() {
        var policy = SelectionCopyTriggerPolicy(doubleCopyInterval: 0.8)
        _ = policy.recordCopy(at: 10)

        XCTAssertTrue(policy.recordCopy(at: 10.5))
    }

    func testSecondCopyAfterIntervalDoesNotTrigger() {
        var policy = SelectionCopyTriggerPolicy(doubleCopyInterval: 0.8)
        _ = policy.recordCopy(at: 10)

        XCTAssertFalse(policy.recordCopy(at: 10.9))
    }
}
