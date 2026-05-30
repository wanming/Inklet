public enum PermissionSettingsRestorePolicy {
    public static func shouldRestore(
        afterDeactivatingApplicationWithBundleIdentifier bundleIdentifier: String?
    ) -> Bool {
        bundleIdentifier == "com.apple.systempreferences"
    }
}
