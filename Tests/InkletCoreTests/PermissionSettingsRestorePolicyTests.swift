import Testing
@testable import InkletCore

struct PermissionSettingsRestorePolicyTests {
    @Test
    func restoresAfterSystemSettingsDeactivates() {
        #expect(
            PermissionSettingsRestorePolicy.shouldRestore(
                afterDeactivatingApplicationWithBundleIdentifier: "com.apple.systempreferences"
            )
        )
    }

    @Test
    func doesNotRestoreAfterUnrelatedApplicationDeactivates() {
        #expect(
            !PermissionSettingsRestorePolicy.shouldRestore(
                afterDeactivatingApplicationWithBundleIdentifier: "com.apple.TextEdit"
            )
        )
    }
}
