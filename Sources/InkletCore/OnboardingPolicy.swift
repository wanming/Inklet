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

    /// Nothing is saved yet and nothing waits to be imported from the sandboxed version.
    public static func isNewInstall(
        hasSavedConfig: Bool,
        hasSavedAPIKey: Bool,
        didCompleteOnboarding: Bool,
        hasPendingMigration: Bool
    ) -> Bool {
        !hasSavedConfig && !hasSavedAPIKey && !didCompleteOnboarding && !hasPendingMigration
    }

    /// New installs on a Mac that can run the built-in engine start with a built-in model, so Inklet
    /// works without an API key. Other Macs keep the usual default.
    public static func initialConfig(isEngineAvailable: Bool, physicalMemoryBytes: UInt64) -> AppConfig? {
        guard isEngineAvailable else { return nil }
        var config = AppConfig.defaultConfig()
        config.providerID = LLMProviderPreset.builtIn.id
        config.model = BuiltInModel.recommended(forPhysicalMemoryBytes: physicalMemoryBytes).id
        return config
    }
}
