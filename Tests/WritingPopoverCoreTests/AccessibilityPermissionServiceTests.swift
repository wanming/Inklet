import XCTest
@testable import WritingPopoverCore

@MainActor
final class AccessibilityPermissionServiceTests: XCTestCase {
    func testRequestOnFirstUsePromptsOnlyOnceWhenUntrusted() {
        let defaults = UserDefaults(suiteName: "AccessibilityPermissionServiceTests.\(UUID().uuidString)")!
        var promptCount = 0
        let service = AccessibilityPermissionService(
            userDefaults: defaults,
            trustChecker: { false },
            promptRequester: {
                promptCount += 1
                return false
            }
        )

        XCTAssertFalse(service.requestOnFirstUse())
        XCTAssertFalse(service.requestOnFirstUse())
        XCTAssertEqual(promptCount, 1)
    }

    func testRequestOnFirstUseDoesNotPromptWhenAlreadyTrusted() {
        let defaults = UserDefaults(suiteName: "AccessibilityPermissionServiceTests.\(UUID().uuidString)")!
        var promptCount = 0
        let service = AccessibilityPermissionService(
            userDefaults: defaults,
            trustChecker: { true },
            promptRequester: {
                promptCount += 1
                return true
            }
        )

        XCTAssertTrue(service.requestOnFirstUse())
        XCTAssertEqual(promptCount, 0)
    }
}
