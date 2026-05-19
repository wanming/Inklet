import ApplicationServices
import Foundation

@MainActor
public struct AccessibilityPermissionService {
    public typealias TrustChecker = @MainActor () -> Bool
    public typealias PromptRequester = @MainActor () -> Bool

    private let userDefaults: UserDefaults
    private let promptFlagKey: String
    private let trustChecker: TrustChecker
    private let promptRequester: PromptRequester

    public init(
        userDefaults: UserDefaults = .standard,
        promptFlagKey: String = "didRequestAccessibilityPermission",
        trustChecker: @escaping TrustChecker = { AXIsProcessTrusted() },
        promptRequester: @escaping PromptRequester = { AccessibilityPermissionService.requestSystemPrompt() }
    ) {
        self.userDefaults = userDefaults
        self.promptFlagKey = promptFlagKey
        self.trustChecker = trustChecker
        self.promptRequester = promptRequester
    }

    public var isTrusted: Bool {
        trustChecker()
    }

    @discardableResult
    public func requestOnFirstUse() -> Bool {
        if isTrusted {
            userDefaults.set(true, forKey: promptFlagKey)
            return true
        }

        guard !userDefaults.bool(forKey: promptFlagKey) else {
            return false
        }

        userDefaults.set(true, forKey: promptFlagKey)
        return promptRequester()
    }

    public static func requestSystemPrompt() -> Bool {
        let options = [
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
