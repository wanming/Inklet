import XCTest
@testable import InkletCore

final class OnboardingPolicyTests: XCTestCase {
    func testNeedsProviderSetupWhenProviderAPIKeyIsMissing() {
        XCTAssertTrue(OnboardingPolicy.needsProviderSetup(providerAPIKey: "  "))
        XCTAssertFalse(OnboardingPolicy.needsProviderSetup(providerAPIKey: "sk-text"))
    }

    func testShowsProviderSetupAfterReturningFromPermissionSettingsWhenAPIKeyIsMissing() {
        XCTAssertTrue(
            OnboardingPolicy.shouldShowProviderSetupAfterReturningFromPermissionSettings(providerAPIKey: "  ")
        )
        XCTAssertFalse(
            OnboardingPolicy.shouldShowProviderSetupAfterReturningFromPermissionSettings(providerAPIKey: "sk-text")
        )
    }

    func testReusesOfficialOpenAIKeyOnlyWhenVoiceKeyIsEmpty() {
        XCTAssertEqual(
            OnboardingPolicy.voiceAPIKey(
                providerID: LLMProviderPreset.openAI.id,
                providerAPIKey: " sk-text ",
                existingVoiceAPIKey: ""
            ),
            "sk-text"
        )
        XCTAssertEqual(
            OnboardingPolicy.voiceAPIKey(
                providerID: LLMProviderPreset.openAI.id,
                providerAPIKey: "sk-text",
                existingVoiceAPIKey: "sk-voice"
            ),
            "sk-voice"
        )
        XCTAssertEqual(
            OnboardingPolicy.voiceAPIKey(
                providerID: LLMProviderPreset.customOpenAICompatible.id,
                providerAPIKey: "sk-custom",
                existingVoiceAPIKey: ""
            ),
            ""
        )
    }

    func testConfiguresVoiceShortcutMonitoringOnlyAfterAccessibilityIsTrusted() {
        XCTAssertFalse(OnboardingPolicy.shouldConfigureVoiceShortcutMonitoring(isAccessibilityTrusted: false))
        XCTAssertTrue(OnboardingPolicy.shouldConfigureVoiceShortcutMonitoring(isAccessibilityTrusted: true))
    }

    func testShowsVoiceShortcutHintOnlyWhenVoiceInputIsConfiguredAndEnabled() {
        XCTAssertTrue(OnboardingPolicy.shouldShowVoiceShortcutHint(
            voiceAPIKey: "sk-voice",
            shortcut: .rightOption
        ))
        XCTAssertFalse(OnboardingPolicy.shouldShowVoiceShortcutHint(
            voiceAPIKey: "  ",
            shortcut: .rightOption
        ))
        XCTAssertFalse(OnboardingPolicy.shouldShowVoiceShortcutHint(
            voiceAPIKey: "sk-voice",
            shortcut: .disabled
        ))
    }

    func testOpensPopoverWhenClosingSettingsAfterCompletingOnboarding() {
        XCTAssertTrue(OnboardingPolicy.shouldOpenPopoverAfterClosingSettings(
            didOpenAccessibilitySettings: true,
            isAccessibilityTrusted: true,
            providerAPIKey: "sk-text",
            didCompleteOnboarding: false
        ))
        XCTAssertFalse(OnboardingPolicy.shouldOpenPopoverAfterClosingSettings(
            didOpenAccessibilitySettings: false,
            isAccessibilityTrusted: true,
            providerAPIKey: "sk-text",
            didCompleteOnboarding: false
        ))
        XCTAssertFalse(OnboardingPolicy.shouldOpenPopoverAfterClosingSettings(
            didOpenAccessibilitySettings: true,
            isAccessibilityTrusted: true,
            providerAPIKey: "",
            didCompleteOnboarding: false
        ))
        XCTAssertFalse(OnboardingPolicy.shouldOpenPopoverAfterClosingSettings(
            didOpenAccessibilitySettings: true,
            isAccessibilityTrusted: true,
            providerAPIKey: "sk-text",
            didCompleteOnboarding: true
        ))
    }
}
