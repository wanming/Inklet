import XCTest
@testable import InkletCore

final class SelectionDismissalPolicyTests: XCTestCase {
    func testDismissalIsAllowedWithoutCandidateSelection() {
        let policy = SelectionDismissalPolicy(candidateGraceInterval: 0.9)

        XCTAssertTrue(policy.shouldDismiss(at: 10))
    }

    func testDismissalIsSuppressedDuringCandidateGraceInterval() {
        var policy = SelectionDismissalPolicy(candidateGraceInterval: 0.9)
        policy.recordCandidate(at: 10)

        XCTAssertFalse(policy.shouldDismiss(at: 10.5))
    }

    func testDismissalIsAllowedAfterCandidateGraceInterval() {
        var policy = SelectionDismissalPolicy(candidateGraceInterval: 0.9)
        policy.recordCandidate(at: 10)

        XCTAssertTrue(policy.shouldDismiss(at: 10.91))
    }
}
