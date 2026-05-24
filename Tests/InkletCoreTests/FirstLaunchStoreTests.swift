import XCTest
@testable import InkletCore

final class FirstLaunchStoreTests: XCTestCase {
    func testNeedsSetupWindowUntilMarkedSeen() throws {
        let suiteName = "FirstLaunchStoreTests.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }
        let store = UserDefaultsFirstLaunchStore(userDefaults: userDefaults)

        XCTAssertTrue(store.needsSetupWindow)

        store.markSetupWindowSeen()

        XCTAssertFalse(store.needsSetupWindow)
    }

    func testExistingConfigDoesNotNeedSetupWindow() throws {
        let suiteName = "FirstLaunchStoreTests.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }
        userDefaults.set(Data(), forKey: UserDefaultsConfigStore.defaultKey)
        let store = UserDefaultsFirstLaunchStore(userDefaults: userDefaults)

        XCTAssertFalse(store.needsSetupWindow)
    }
}
