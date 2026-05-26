import Foundation
import IOKit.hid

@MainActor
public struct InputMonitoringPermissionService {
    public typealias TrustChecker = @MainActor () -> Bool
    public typealias PromptRequester = @MainActor () -> Bool

    private let trustChecker: TrustChecker
    private let promptRequester: PromptRequester

    public init(
        trustChecker: @escaping TrustChecker = { InputMonitoringPermissionService.checkSystemAccess() },
        promptRequester: @escaping PromptRequester = { InputMonitoringPermissionService.requestSystemPrompt() }
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

    public static func checkSystemAccess() -> Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    public static func requestSystemPrompt() -> Bool {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }
}
