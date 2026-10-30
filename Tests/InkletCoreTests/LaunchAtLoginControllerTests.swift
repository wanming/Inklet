import ServiceManagement
import XCTest
@testable import Inklet

@MainActor
final class LaunchAtLoginControllerTests: XCTestCase {
    func testStartsOffAndTurnsOnByRegistering() {
        let service = FakeLoginItemService(status: .notRegistered)
        let controller = LaunchAtLoginController(service: service)

        XCTAssertFalse(controller.isEnabled)
        XCTAssertNil(controller.warning)

        controller.setEnabled(true)

        XCTAssertEqual(service.registerCount, 1)
        XCTAssertTrue(controller.isEnabled)
        XCTAssertNil(controller.warning)
    }

    func testTurningOffUnregistersAndRepeatedChoicesDoNothing() {
        let service = FakeLoginItemService(status: .enabled)
        let controller = LaunchAtLoginController(service: service)

        controller.setEnabled(true)
        XCTAssertEqual(service.registerCount, 0)

        controller.setEnabled(false)
        controller.setEnabled(false)

        XCTAssertEqual(service.unregisterCount, 1)
        XCTAssertFalse(controller.isEnabled)
    }

    func testWaitingForApprovalStaysOnAndExplainsWhere() {
        let service = FakeLoginItemService(status: .notRegistered)
        service.statusAfterRegister = .requiresApproval
        let controller = LaunchAtLoginController(service: service)

        controller.setEnabled(true)

        XCTAssertTrue(controller.isEnabled)
        XCTAssertTrue(controller.needsApproval)
        XCTAssertEqual(controller.warning, L10n.text("settings.launchAtLogin.needsApproval"))
    }

    func testFailureKeepsTheSystemStateAndClearsOnRefresh() {
        let service = FakeLoginItemService(status: .notRegistered)
        service.registerError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Denied"])
        let controller = LaunchAtLoginController(service: service)

        controller.setEnabled(true)

        XCTAssertFalse(controller.isEnabled)
        XCTAssertEqual(controller.warning, L10n.format("settings.launchAtLogin.failed", "Denied"))

        controller.refresh()

        XCTAssertNil(controller.warning)
    }

    func testRefreshFollowsAChangeMadeInSystemSettings() {
        let service = FakeLoginItemService(status: .enabled)
        let controller = LaunchAtLoginController(service: service)

        service.status = .notRegistered
        controller.refresh()

        XCTAssertFalse(controller.isEnabled)
    }
}

private final class FakeLoginItemService: LoginItemService {
    var status: SMAppService.Status
    var statusAfterRegister: SMAppService.Status = .enabled
    var registerError: Error?
    private(set) var registerCount = 0
    private(set) var unregisterCount = 0

    init(status: SMAppService.Status) {
        self.status = status
    }

    func register() throws {
        if let registerError {
            throw registerError
        }
        registerCount += 1
        status = statusAfterRegister
    }

    func unregister() throws {
        unregisterCount += 1
        status = .notRegistered
    }
}
