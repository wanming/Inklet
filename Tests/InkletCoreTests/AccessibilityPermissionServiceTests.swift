import XCTest
@testable import InkletCore

@MainActor
final class AccessibilityPermissionServiceTests: XCTestCase {
    func testRequestIfNeededPromptsWhenUntrusted() {
        var promptCount = 0
        let service = AccessibilityPermissionService(
            trustChecker: { false },
            promptRequester: {
                promptCount += 1
                return false
            }
        )

        XCTAssertFalse(service.requestIfNeeded())
        XCTAssertFalse(service.requestIfNeeded())
        XCTAssertEqual(promptCount, 2)
    }

    func testRequestIfNeededDoesNotPromptWhenAlreadyTrusted() {
        var promptCount = 0
        let service = AccessibilityPermissionService(
            trustChecker: { true },
            promptRequester: {
                promptCount += 1
                return true
            }
        )

        XCTAssertTrue(service.requestIfNeeded())
        XCTAssertEqual(promptCount, 0)
    }
}
