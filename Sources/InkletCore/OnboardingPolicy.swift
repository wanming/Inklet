import Foundation

public enum OnboardingPolicy {
    public static func shouldConfigureVoiceShortcutMonitoring(isAccessibilityTrusted: Bool) -> Bool {
        isAccessibilityTrusted
    }

    public static func shouldShowVoiceShortcutHint(
        voiceAPIKey: String?,
        shortcut: VoiceInputConfig.Shortcut
    ) -> Bool {
        voiceAPIKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && shortcut != .disabled
    }

    public static func needsProviderSetup(providerAPIKey: String?) -> Bool {
        providerAPIKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false
    }

    public static func shouldOpenPopoverAfterClosingSettings(
        didOpenAccessibilitySettings: Bool,
        isAccessibilityTrusted: Bool,
        providerAPIKey: String?,
        didCompleteOnboarding: Bool
    ) -> Bool {
        didOpenAccessibilitySettings
            && isAccessibilityTrusted
            && !needsProviderSetup(providerAPIKey: providerAPIKey)
            && !didCompleteOnboarding
    }

    public static func voiceAPIKey(
        providerID: String,
        providerAPIKey: String,
        existingVoiceAPIKey: String
    ) -> String {
        let trimmedVoiceAPIKey = existingVoiceAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard providerID == LLMProviderPreset.openAI.id, trimmedVoiceAPIKey.isEmpty else {
            return trimmedVoiceAPIKey
        }

        return providerAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
