import XCTest
@testable import InkletCore

final class SelectionMenuButtonsTests: XCTestCase {
    private let modes = PromptModeStore.defaultStore().modes

    func testDefaultMenuShowsTranslateAndPronounceOnly() {
        let config = SelectionActionsConfig.defaultConfig()

        XCTAssertEqual(config.enabledMenuButtons(promptModes: modes).map(\.action), [.translate, .pronounce])
        XCTAssertEqual(
            config.menuButtons(promptModes: modes).map(\.action),
            [.translate, .pronounce] + modes.sorted { $0.sortOrder < $1.sortOrder }.map { .promptMode($0.id) }
        )
    }

    func testStorageIDRoundTrips() {
        for action in [SelectionMenuAction.translate, .pronounce, .promptMode("custom-1")] {
            XCTAssertEqual(SelectionMenuAction(storageID: action.storageID), action)
        }
        XCTAssertNil(SelectionMenuAction(storageID: "mode:"))
        XCTAssertNil(SelectionMenuAction(storageID: "unknown"))
    }

    func testEnablingPromptModeAddsItToMenu() {
        var config = SelectionActionsConfig.defaultConfig()

        config.setMenuButton(.promptMode(PromptMode.chineseSummaryID), isEnabled: true, promptModes: modes)

        XCTAssertEqual(
            config.enabledMenuButtons(promptModes: modes).map(\.action),
            [.translate, .pronounce, .promptMode(PromptMode.chineseSummaryID)]
        )
    }

    func testMovingButtonsChangesOrder() {
        var config = SelectionActionsConfig.defaultConfig()
        config.setMenuButton(.promptMode(PromptMode.chineseSummaryID), isEnabled: true, promptModes: modes)
        let summaryIndex = config.menuButtons(promptModes: modes)
            .firstIndex { $0.action == .promptMode(PromptMode.chineseSummaryID) }!

        config.moveMenuButtons(from: IndexSet(integer: summaryIndex), to: 0, promptModes: modes)

        XCTAssertEqual(
            config.enabledMenuButtons(promptModes: modes).map(\.action),
            [.promptMode(PromptMode.chineseSummaryID), .translate, .pronounce]
        )
    }

    func testLastEnabledButtonCannotBeTurnedOff() {
        var config = SelectionActionsConfig.defaultConfig()

        config.setMenuButton(.pronounce, isEnabled: false, promptModes: modes)
        config.setMenuButton(.translate, isEnabled: false, promptModes: modes)

        XCTAssertEqual(config.enabledMenuButtons(promptModes: modes).map(\.action), [.translate])
    }

    func testDeletedPromptModesAreDroppedAndNewOnesAppendedOff() {
        let config = SelectionActionsConfig(menuButtonSettings: [
            SelectionMenuButtonSetting(id: "mode:deleted", isEnabled: true),
            SelectionMenuButtonSetting(id: "pronounce", isEnabled: true),
            SelectionMenuButtonSetting(id: "translate", isEnabled: false)
        ])

        let buttons = config.menuButtons(promptModes: modes)

        XCTAssertEqual(Array(buttons.prefix(2)).map(\.action), [.pronounce, .translate])
        XCTAssertFalse(buttons.contains { $0.action == .promptMode("deleted") })
        XCTAssertTrue(buttons.dropFirst(2).allSatisfy { !$0.isEnabled })
    }

    func testMenuButtonsSurviveEncoding() throws {
        var config = SelectionActionsConfig.defaultConfig()
        config.setMenuButton(.promptMode(PromptMode.translateToEnglishID), isEnabled: true, promptModes: modes)

        let decoded = try JSONDecoder().decode(
            SelectionActionsConfig.self,
            from: JSONEncoder().encode(config)
        )

        XCTAssertEqual(decoded.menuButtonSettings, config.menuButtonSettings)
    }

    func testLayoutMovesExtraButtonsIntoOverflow() {
        let buttons = (0..<6).map { SelectionMenuButton(action: .promptMode("m\($0)"), isEnabled: true) }

        let fitting = SelectionMenuLayout.split(Array(buttons.prefix(4)))
        XCTAssertEqual(fitting.inline.count, 4)
        XCTAssertTrue(fitting.overflow.isEmpty)

        let overflowing = SelectionMenuLayout.split(buttons)
        XCTAssertEqual(overflowing.inline.map(\.id), buttons.prefix(3).map(\.id))
        XCTAssertEqual(overflowing.overflow.map(\.id), buttons.dropFirst(3).map(\.id))
    }
}
