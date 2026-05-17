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
        config.model = "test-model"
        config.temperature = 0.7
        config.timeoutSeconds = 9
        config.hotkey = "⌘Space"
        config.defaultModeID = PromptMode.polishEnglishID
        config.promptModes = [
            PromptMode(
                id: "custom-test-mode",
                name: "Custom Test Mode",
                description: "Custom test description",
                systemPrompt: "Custom test prompt",
                shortcut: "⌘9",
                participatesInAuto: true,
                autoRule: .englishHeavy,
                sortOrder: 99,
                isVisible: false
            )
        ]

        try store.save(config)
        let loadedConfig = try store.load()

        XCTAssertEqual(loadedConfig, config)
    }
}
