import Foundation

public protocol FirstLaunchStore {
    var needsSetupWindow: Bool { get }
    func markSetupWindowSeen()
}

public struct UserDefaultsFirstLaunchStore: FirstLaunchStore {
    public static let defaultKey = "hasSeenSetupWindow"

    private let userDefaults: UserDefaults
    private let key: String
    private let existingConfigKey: String

    public init(
        userDefaults: UserDefaults = .standard,
        key: String = UserDefaultsFirstLaunchStore.defaultKey,
        existingConfigKey: String = UserDefaultsConfigStore.defaultKey
    ) {
        self.userDefaults = userDefaults
        self.key = key
        self.existingConfigKey = existingConfigKey
    }

    public var needsSetupWindow: Bool {
        !userDefaults.bool(forKey: key) && userDefaults.object(forKey: existingConfigKey) == nil
    }

    public func markSetupWindowSeen() {
        userDefaults.set(true, forKey: key)
    }
}
