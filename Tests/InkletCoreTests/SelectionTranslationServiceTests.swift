import XCTest
@testable import InkletCore

final class SelectionTranslationServiceTests: XCTestCase {
    func testBuildsTranslationPromptMode() {
        let mode = SelectionTranslationService.promptMode(targetLanguageName: "Simplified Chinese")

        XCTAssertEqual(mode.id, "selection-action-translate")
        XCTAssertFalse(mode.isVisible)
        XCTAssertTrue(mode.systemPrompt.contains("Simplified Chinese"))
        XCTAssertTrue(mode.systemPrompt.contains("Return only the translated text."))
    }

    func testTranslatesWithInjectedService() async throws {
        let service = SelectionTranslationService(
            transform: { source, targetLanguageName, model, temperature, timeoutSeconds in
                XCTAssertEqual(source, "hello")
                XCTAssertEqual(targetLanguageName, "Japanese")
                XCTAssertEqual(model, "test-model")
                XCTAssertEqual(temperature, 0.2)
                XCTAssertEqual(timeoutSeconds, 3)
                return "こんにちは"
            }
        )

        let result = try await service.translate(
            sourceText: "hello",
            targetLanguageName: "Japanese",
            model: "test-model",
            temperature: 0.2,
            timeoutSeconds: 3
        )

        XCTAssertEqual(result, "こんにちは")
    }
}
