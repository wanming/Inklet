import XCTest
@testable import WritingPopoverCore

final class PromptModeTests: XCTestCase {
    func testDefaultModesContainAutoTranslationAndPolishing() {
        let store = PromptModeStore.defaultStore()

        XCTAssertEqual(store.visibleModes.map(\.name), ["Auto", "Chinese to English", "Polish English", "Custom Prompt"])
    }

    func testAutoResolvesChineseHeavyInputToTranslationMode() {
        let store = PromptModeStore.defaultStore()

        let mode = store.resolve(modeID: PromptMode.autoID, sourceText: "请帮我写一封英文邮件")

        XCTAssertEqual(mode.name, "Chinese to English")
    }

    func testAutoResolvesEnglishHeavyInputToPolishingMode() {
        let store = PromptModeStore.defaultStore()

        let mode = store.resolve(modeID: PromptMode.autoID, sourceText: "i has a apple")

        XCTAssertEqual(mode.name, "Polish English")
    }

    func testHiddenModesAreExcludedFromVisibleModes() {
        var store = PromptModeStore.defaultStore()
        store.upsert(PromptMode(
            id: "hidden",
            name: "Hidden",
            description: "hidden mode",
            systemPrompt: "hidden prompt",
            shortcut: nil,
            participatesInAuto: false,
            autoRule: .none,
            sortOrder: 1,
            isVisible: false
        ))

        XCTAssertFalse(store.visibleModes.contains { $0.id == "hidden" })
    }
}
