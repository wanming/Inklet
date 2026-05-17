import XCTest
@testable import WritingPopoverCore

final class ConfigStoreTests: XCTestCase {
    func testDefaultConfigMatchesSpec() {
        let config = AppConfig.defaultConfig()

        XCTAssertEqual(config.model, "gpt-4.1-mini")
        XCTAssertEqual(config.temperature, 0.2)
        XCTAssertEqual(config.timeoutSeconds, 20)
        XCTAssertEqual(config.hotkey, "⌥Space")
        XCTAssertEqual(config.defaultModeID, PromptMode.autoID)
    }

    func testConfigRoundTripsThroughUserDefaults() throws {
        let suiteName = "ConfigStoreTests.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }
        let store = UserDefaultsConfigStore(userDefaults: userDefaults)
        var config = AppConfig.defaultConfig()
        config.model = "gpt-4.1"
        config.temperature = 0.7

        try store.save(config)
        let loadedConfig = try store.load()

        XCTAssertEqual(loadedConfig.model, "gpt-4.1")
        XCTAssertEqual(loadedConfig.temperature, 0.7)
    }
}
