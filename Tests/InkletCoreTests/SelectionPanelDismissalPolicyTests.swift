import XCTest
@testable import InkletCore

final class SelectionPanelDismissalPolicyTests: XCTestCase {
    func testDismissalIsAllowedBeforePanelIsShown() {
        let policy = SelectionPanelDismissalPolicy(graceInterval: 3)

        XCTAssertTrue(policy.shouldDismiss(at: 10))
    }

    func testDefaultSuppressesStaleDismissalImmediatelyAfterPanelIsShown() {
        var policy = SelectionPanelDismissalPolicy()
        policy.recordPanelShown(at: 10)

        XCTAssertFalse(policy.shouldDismiss(at: 10))
    }

    func testDefaultAllowsMouseDismissalImmediatelyAfterPanelIsShown() {
        var policy = SelectionPanelDismissalPolicy()
        policy.recordPanelShown(at: 10)

        XCTAssertTrue(policy.shouldDismiss(at: 10, bypassingGrace: true))
    }

    func testDismissalIsSuppressedShortlyAfterPanelIsShown() {
        var policy = SelectionPanelDismissalPolicy(graceInterval: 3)
        policy.recordPanelShown(at: 10)

        XCTAssertFalse(policy.shouldDismiss(at: 12))
    }

    func testDismissalIsAllowedAfterGraceInterval() {
        var policy = SelectionPanelDismissalPolicy(graceInterval: 3)
        policy.recordPanelShown(at: 10)

        XCTAssertTrue(policy.shouldDismiss(at: 13))
    }
}
