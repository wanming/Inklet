import CoreGraphics
import Foundation

@MainActor
public struct InputMonitoringPermissionService {
    public typealias TrustChecker = @MainActor () -> Bool

    private let trustChecker: TrustChecker

    public init(
        trustChecker: @escaping TrustChecker = { InputMonitoringPermissionService.checkSystemAccess() }
    ) {
        self.trustChecker = trustChecker
    }

    public var isTrusted: Bool {
        trustChecker()
    }

    public static func checkSystemAccess() -> Bool {
        CGPreflightListenEventAccess()
    }
}
