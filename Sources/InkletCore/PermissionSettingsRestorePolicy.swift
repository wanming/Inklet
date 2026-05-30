public enum PermissionSettingsRestorePolicy {
    public static func shouldRestore(
        didObserveSystemSettingsRunning: Bool,
        isSystemSettingsRunning: Bool
    ) -> Bool {
        didObserveSystemSettingsRunning && !isSystemSettingsRunning
    }

    public static func shouldRefreshAccessibilityServicesAfterRestore(
        didObserveSystemSettingsRunning: Bool,
        isSystemSettingsRunning: Bool,
        isAccessibilityTrusted: Bool
    ) -> Bool {
        shouldRestore(
            didObserveSystemSettingsRunning: didObserveSystemSettingsRunning,
            isSystemSettingsRunning: isSystemSettingsRunning
        ) && isAccessibilityTrusted
    }
}
