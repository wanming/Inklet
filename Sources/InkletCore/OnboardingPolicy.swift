import Foundation

public enum OnboardingPolicy {
    public static func shouldShowVoiceShortcutHint(
        openAIAPIKey: String?,
        shortcut: VoiceInputConfig.Shortcut
    ) -> Bool {
        openAIAPIKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && shortcut != .disabled
    }

    public static func needsProviderSetup(providerAPIKey: String?, requiresAPIKey: Bool = true) -> Bool {
        requiresAPIKey && providerAPIKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false
    }

    public static func shouldShowProviderSetupAfterReturningFromPermissionSettings(
        providerAPIKey: String?,
        requiresAPIKey: Bool = true
    ) -> Bool {
        needsProviderSetup(providerAPIKey: providerAPIKey, requiresAPIKey: requiresAPIKey)
    }

    public static func shouldOpenPopoverAfterClosingSettings(
        didOpenAccessibilitySettings: Bool,
        isAccessibilityTrusted: Bool,
        providerAPIKey: String?,
        requiresAPIKey: Bool = true,
        didCompleteOnboarding: Bool
    ) -> Bool {
        didOpenAccessibilitySettings
            && isAccessibilityTrusted
            && !needsProviderSetup(providerAPIKey: providerAPIKey, requiresAPIKey: requiresAPIKey)
            && !didCompleteOnboarding
    }

}
