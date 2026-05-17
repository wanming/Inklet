import XCTest
@testable import WritingPopoverCore

final class PromptModeTests: XCTestCase {
    private struct AutoRulePayload: Codable {
        var autoRule: PromptMode.AutoRule
    }

    func testDefaultModesContainAutoTranslationAndPolishing() {
        let store = PromptModeStore.defaultStore()

        XCTAssertEqual(store.visibleModes.map(\.name), ["Auto", "Chinese to English", "Polish English", "Custom Prompt"])
    }

    func testAutoResolvesChineseHeavyInputToTranslationMode() {
        let store = PromptModeStore.defaultStore()

        let mode = store.resolve(modeID: PromptMode.autoID, sourceText: "请帮我写一封英文邮件")

        XCTAssertEqual(mode.id, PromptMode.chineseToEnglishID)
    }

    func testAutoResolvesEnglishHeavyInputToPolishingMode() {
        let store = PromptModeStore.defaultStore()

        let mode = store.resolve(modeID: PromptMode.autoID, sourceText: "i has a apple")

        XCTAssertEqual(mode.id, PromptMode.polishEnglishID)
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

    func testEmptyStoreResolveFallsBackToBuiltInPolishEnglishMode() {
        let store = PromptModeStore(modes: [])

        let mode = store.resolve(modeID: PromptMode.autoID, sourceText: "hello")

        XCTAssertEqual(mode.id, PromptMode.polishEnglishID)
    }

    func testUnknownAutoRuleDecodesAsNone() throws {
        let data = #"{"autoRule":"renamed-rule"}"#.data(using: .utf8)!

        let payload = try JSONDecoder().decode(AutoRulePayload.self, from: data)

        XCTAssertEqual(payload.autoRule, .none)
    }
}
