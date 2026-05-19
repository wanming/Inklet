import XCTest
@testable import WritingPopoverCore

final class PromptModeTests: XCTestCase {
    private struct AutoRulePayload: Codable {
        var autoRule: PromptMode.AutoRule
    }

    func testDefaultModesAreMultilingualWritingModesWithoutAuto() {
        let store = PromptModeStore.defaultStore()

        XCTAssertEqual(store.visibleModes.map(\.name), [
            "Translate to English",
            "Improve Writing",
            "Make Concise",
            "Professional Tone",
            "Friendly Reply",
            "Custom Prompt"
        ])
        XCTAssertFalse(store.visibleModes.contains { $0.id == PromptMode.autoID })
    }

    func testResolveReturnsSelectedModeWhenAvailable() {
        let store = PromptModeStore.defaultStore()

        let mode = store.resolve(modeID: PromptMode.makeConciseID, sourceText: "Please make this shorter.")

        XCTAssertEqual(mode.id, PromptMode.makeConciseID)
    }

    func testResolveFallsBackToTranslateToEnglishForMissingMode() {
        let store = PromptModeStore.defaultStore()

        let mode = store.resolve(modeID: "missing", sourceText: "hello")

        XCTAssertEqual(mode.id, PromptMode.translateToEnglishID)
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

    func testEmptyStoreResolveFallsBackToBuiltInTranslateToEnglishMode() {
        let store = PromptModeStore(modes: [])

        let mode = store.resolve(modeID: "missing", sourceText: "hello")

        XCTAssertEqual(mode.id, PromptMode.translateToEnglishID)
    }

    func testUnknownAutoRuleDecodesAsNone() throws {
        let data = #"{"autoRule":"renamed-rule"}"#.data(using: .utf8)!

        let payload = try JSONDecoder().decode(AutoRulePayload.self, from: data)

        XCTAssertEqual(payload.autoRule, .none)
    }
}
