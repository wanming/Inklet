import XCTest
@testable import InkletCore

@MainActor
final class InputMonitoringPermissionServiceTests: XCTestCase {
    func testIsTrustedUsesInjectedTrustChecker() {
        let service = InputMonitoringPermissionService(
            trustChecker: { true }
        )

        XCTAssertTrue(service.isTrusted)
    }

    func testIsTrustedCanReportUntrusted() {
        let service = InputMonitoringPermissionService(
            trustChecker: { false }
        )

        XCTAssertFalse(service.isTrusted)
    }
}
