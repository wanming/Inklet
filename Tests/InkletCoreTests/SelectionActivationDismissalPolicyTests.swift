import XCTest
@testable import InkletCore

final class SelectionActivationDismissalPolicyTests: XCTestCase {
    func testDoesNotDismissWhenCurrentAppActivatesItsOwnPanel() {
        XCTAssertFalse(SelectionActivationDismissalPolicy.shouldDismiss(
            activatedProcessIdentifier: 42,
            currentProcessIdentifier: 42
        ))
    }

    func testDismissesWhenAnotherAppActivates() {
        XCTAssertTrue(SelectionActivationDismissalPolicy.shouldDismiss(
            activatedProcessIdentifier: 99,
            currentProcessIdentifier: 42
        ))
    }

    func testDoesNotDismissWhenActivatedApplicationIsMissing() {
        XCTAssertFalse(SelectionActivationDismissalPolicy.shouldDismiss(
            activatedProcessIdentifier: nil,
            currentProcessIdentifier: 42
        ))
    }
}
