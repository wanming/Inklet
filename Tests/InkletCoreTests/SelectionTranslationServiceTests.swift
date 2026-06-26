import XCTest
@testable import InkletCore

final class SelectionTranslationServiceTests: XCTestCase {
    func testBuildsTranslationPromptMode() {
        let mode = SelectionTranslationService.promptMode(systemPrompt: "Custom selection prompt.")

        XCTAssertEqual(mode.id, "selection-action-translate")
        XCTAssertFalse(mode.isVisible)
        XCTAssertEqual(mode.systemPrompt, "Custom selection prompt.")
    }

    func testTranslatesWithInjectedService() async throws {
        let service = SelectionTranslationService(
            transform: { source, systemPrompt, model, temperature, timeoutSeconds in
                XCTAssertEqual(source, "hello")
                XCTAssertEqual(systemPrompt, "Translate into Japanese.")
                XCTAssertEqual(model, "test-model")
                XCTAssertEqual(temperature, 0.2)
                XCTAssertEqual(timeoutSeconds, 3)
                return "こんにちは"
            }
        )

        let result = try await service.translate(
            sourceText: "hello",
            systemPrompt: "Translate into Japanese.",
            model: "test-model",
            temperature: 0.2,
            timeoutSeconds: 3
        )

        XCTAssertEqual(result, "こんにちは")
    }
}
