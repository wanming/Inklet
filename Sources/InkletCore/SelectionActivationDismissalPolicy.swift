import Foundation

public enum SelectionActivationDismissalPolicy {
    public static func shouldDismiss(
        activatedProcessIdentifier: pid_t?,
        currentProcessIdentifier: pid_t
    ) -> Bool {
        guard let activatedProcessIdentifier else {
            return false
        }

        return activatedProcessIdentifier != currentProcessIdentifier
    }
}
