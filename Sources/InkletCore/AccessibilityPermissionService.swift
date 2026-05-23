import ApplicationServices
import Foundation

@MainActor
public struct AccessibilityPermissionService {
    public typealias TrustChecker = @MainActor () -> Bool
    public typealias PromptRequester = @MainActor () -> Bool

    private let trustChecker: TrustChecker
    private let promptRequester: PromptRequester

    public init(
        trustChecker: @escaping TrustChecker = { AXIsProcessTrusted() },
        promptRequester: @escaping PromptRequester = { AccessibilityPermissionService.requestSystemPrompt() }
    ) {
        self.trustChecker = trustChecker
        self.promptRequester = promptRequester
    }

    public var isTrusted: Bool {
        trustChecker()
    }

    @discardableResult
    public func requestIfNeeded() -> Bool {
        isTrusted || promptRequester()
    }

    public static func requestSystemPrompt() -> Bool {
        let options = [
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
