import Testing
@testable import InkletCore

struct PermissionSettingsRestorePolicyTests {
    @Test
    func restoresAfterObservedSystemSettingsExits() {
        #expect(
            PermissionSettingsRestorePolicy.shouldRestore(
                didObserveSystemSettingsRunning: true,
                isSystemSettingsRunning: false
            )
        )
    }

    @Test
    func doesNotRestoreBeforeSystemSettingsRuns() {
        #expect(
            !PermissionSettingsRestorePolicy.shouldRestore(
                didObserveSystemSettingsRunning: false,
                isSystemSettingsRunning: false
            )
        )
    }

    @Test
    func doesNotRestoreWhileSystemSettingsIsStillRunning() {
        #expect(
            !PermissionSettingsRestorePolicy.shouldRestore(
                didObserveSystemSettingsRunning: true,
                isSystemSettingsRunning: true
            )
        )
    }

    @Test
    func refreshesAccessibilityServicesAfterTrustedSystemSettingsReturn() {
        #expect(
            PermissionSettingsRestorePolicy.shouldRefreshAccessibilityServicesAfterRestore(
                didObserveSystemSettingsRunning: true,
                isSystemSettingsRunning: false,
                isAccessibilityTrusted: true
            )
        )
    }

    @Test
    func doesNotRefreshAccessibilityServicesWhenPermissionIsStillMissing() {
        #expect(
            !PermissionSettingsRestorePolicy.shouldRefreshAccessibilityServicesAfterRestore(
                didObserveSystemSettingsRunning: true,
                isSystemSettingsRunning: false,
                isAccessibilityTrusted: false
            )
        )
    }
}
