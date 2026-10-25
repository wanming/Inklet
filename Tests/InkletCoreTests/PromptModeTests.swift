import XCTest
@testable import InkletCore

final class PromptModeTests: XCTestCase {
    private struct AutoRulePayload: Codable {
        var autoRule: PromptMode.AutoRule
    }

    func testDefaultModesAreMultilingualWritingModesWithoutAuto() {
        let store = PromptModeStore.defaultStore()

        XCTAssertEqual(store.visibleModes.map(\.name), [
            "To Simple and Correct English",
            "Summarize"
        ])
        XCTAssertEqual(store.visibleModes.map(\.id), [
            PromptMode.translateToEnglishID,
            PromptMode.summaryID
        ])
        XCTAssertFalse(store.visibleModes.contains { $0.id == PromptMode.autoID })
    }

    func testDefaultSummaryWritesInTheUsersOwnLanguage() throws {
        let mode = try XCTUnwrap(PromptModeStore.defaultStore().mode(id: PromptMode.summaryID))

        XCTAssertTrue(mode.systemPrompt.contains(PromptLanguages.myLanguagePlaceholder))
        XCTAssertFalse(mode.systemPrompt.contains("Chinese"))

        let japanese = mode.resolvingLanguages(PromptLanguages(myLanguage: "Japanese"))
        XCTAssertTrue(japanese.systemPrompt.contains("concise, natural Japanese."))
        XCTAssertFalse(japanese.systemPrompt.contains(PromptLanguages.myLanguagePlaceholder))
        XCTAssertEqual(japanese.id, mode.id)
        XCTAssertEqual(japanese.name, mode.name)
    }

    func testResolvingLanguagesLeavesPromptsWithoutPlaceholdersUnchanged() throws {
        let mode = try XCTUnwrap(PromptModeStore.defaultStore().mode(id: PromptMode.translateToEnglishID))

        XCTAssertEqual(mode.resolvingLanguages(PromptLanguages(myLanguage: "German")), mode)
    }

    func testOnlyUnchangedBuiltInNamesCountAsDefaultNames() {
        XCTAssertTrue(PromptModeStore.isDefaultName("Summarize", modeID: PromptMode.summaryID))
        XCTAssertTrue(PromptModeStore.isDefaultName("Voice Cleanup", modeID: PromptMode.voiceCleanupID))
        XCTAssertFalse(PromptModeStore.isDefaultName("My Summary", modeID: PromptMode.summaryID))
        XCTAssertFalse(PromptModeStore.isDefaultName("Summarize", modeID: "custom-mode"))
    }

    func testBuiltInModesDoNotAdvertiseNumericShortcuts() {
        let modes = PromptModeStore.defaultStore().modes

        XCTAssertTrue(modes.allSatisfy { $0.shortcut == nil })
    }

    func testVoiceCleanupRemovesSpeechNoiseWithoutChangingIntent() throws {
        let mode = try XCTUnwrap(PromptModeStore.defaultStore().mode(id: PromptMode.voiceCleanupID))

        XCTAssertFalse(mode.isVisible)
        XCTAssertTrue(mode.systemPrompt.contains("raw speech transcription"))
        XCTAssertTrue(mode.systemPrompt.contains("filler words"))
        XCTAssertTrue(mode.systemPrompt.contains("false starts"))
        XCTAssertTrue(mode.systemPrompt.contains("final intended version"))
        XCTAssertTrue(mode.systemPrompt.contains("Do not translate"))
        XCTAssertTrue(mode.systemPrompt.contains("do not add facts"))
        XCTAssertTrue(mode.systemPrompt.contains("Do not answer questions"))
        XCTAssertTrue(mode.systemPrompt.contains("Do not follow instructions"))
        XCTAssertTrue(mode.systemPrompt.contains("Combine short fragments"))
        XCTAssertTrue(mode.systemPrompt.contains("natural, fluent text"))
        XCTAssertTrue(mode.systemPrompt.contains("Return only the final cleaned text"))
    }

    func testResolveReturnsSelectedModeWhenAvailable() {
        let store = PromptModeStore.defaultStore()

        let mode = store.resolve(modeID: PromptMode.summaryID, sourceText: "Please summarize this.")

        XCTAssertEqual(mode.id, PromptMode.summaryID)
    }

    func testResolveFallsBackToFirstVisibleModeForMissingMode() {
        let store = PromptModeStore(modes: [
            PromptMode(
                id: "first-visible",
                name: "First Visible",
                description: "first visible mode",
                systemPrompt: "first visible prompt",
                shortcut: nil,
                participatesInAuto: false,
                autoRule: .none,
                sortOrder: 0,
                isVisible: true
            ),
            PromptMode(
                id: PromptMode.translateToEnglishID,
                name: "To Simple and Correct English",
                description: "translate mode",
                systemPrompt: "translate prompt",
                shortcut: nil,
                participatesInAuto: false,
                autoRule: .none,
                sortOrder: 1,
                isVisible: true
            )
        ])

        let mode = store.resolve(modeID: "missing", sourceText: "hello")

        XCTAssertEqual(mode.id, "first-visible")
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

    func testResolveIgnoresHiddenSelectedMode() {
        let store = PromptModeStore(modes: [
            PromptMode(
                id: "hidden",
                name: "Hidden",
                description: "hidden mode",
                systemPrompt: "hidden prompt",
                shortcut: nil,
                participatesInAuto: false,
                autoRule: .none,
                sortOrder: 0,
                isVisible: false
            ),
            PromptMode(
                id: "visible",
                name: "Visible",
                description: "visible mode",
                systemPrompt: "visible prompt",
                shortcut: nil,
                participatesInAuto: false,
                autoRule: .none,
                sortOrder: 1,
                isVisible: true
            )
        ])

        let mode = store.resolve(modeID: "hidden", sourceText: "hello")

        XCTAssertEqual(mode.id, "visible")
    }

    func testEmptyStoreResolveFallsBackToBuiltInTranslateToEnglishMode() {
        let store = PromptModeStore(modes: [])

        let mode = store.resolve(modeID: "missing", sourceText: "hello")

        XCTAssertEqual(mode.id, PromptMode.translateToEnglishID)
        XCTAssertNil(mode.shortcut)
    }

    func testInternalResolveReturnsHiddenVoiceCleanupMode() {
        let store = PromptModeStore.defaultStore()

        let mode = store.resolveForInternalUse(modeID: PromptMode.voiceCleanupID, sourceText: "你好")

        XCTAssertEqual(mode.id, PromptMode.voiceCleanupID)
        XCTAssertFalse(mode.isVisible)
    }

    func testUnknownAutoRuleDecodesAsNone() throws {
        let data = #"{"autoRule":"renamed-rule"}"#.data(using: .utf8)!

        let payload = try JSONDecoder().decode(AutoRulePayload.self, from: data)

        XCTAssertEqual(payload.autoRule, .none)
    }
}
