import XCTest
@testable import InkletCore

@MainActor
final class InputMonitoringPermissionServiceTests: XCTestCase {
    func testRequestIfNeededDoesNotPromptWhenAlreadyTrusted() {
        var didPrompt = false
        let service = InputMonitoringPermissionService(
            trustChecker: { true },
            promptRequester: {
                didPrompt = true
                return false
            }
        )

        XCTAssertTrue(service.requestIfNeeded())
        XCTAssertFalse(didPrompt)
    }

    func testRequestIfNeededPromptsWhenUntrusted() {
        var didPrompt = false
        let service = InputMonitoringPermissionService(
            trustChecker: { false },
            promptRequester: {
                didPrompt = true
                return true
            }
        )

        XCTAssertTrue(service.requestIfNeeded())
        XCTAssertTrue(didPrompt)
    }
}
