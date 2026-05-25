import XCTest
@testable import InkletCore

final class VoiceInputConfigTests: XCTestCase {
    func testDefaultVoiceInputConfigMatchesSpec() {
        let config = VoiceInputConfig.defaultConfig()

        XCTAssertEqual(config.shortcut, .rightOption)
        XCTAssertEqual(config.speechProviderID, VoiceInputConfig.openAISpeechProviderID)
        XCTAssertEqual(config.speechEndpoint, "https://api.openai.com/v1/audio/transcriptions")
        XCTAssertEqual(config.speechModel, "gpt-4o-mini-transcribe")
        XCTAssertTrue(config.autoProcessTranscription)
        XCTAssertEqual(config.voiceCleanupPromptModeID, PromptMode.voiceCleanupID)
    }

    func testAppConfigDefaultsIncludeVoiceInputConfig() {
        let config = AppConfig.defaultConfig()

        XCTAssertEqual(config.voiceInput, VoiceInputConfig.defaultConfig())
    }

    func testAppConfigDecodeFallsBackToVoiceDefaultsForMissingFields() throws {
        let data = #"{"model":"saved-model"}"#.data(using: .utf8)!

        let config = try JSONDecoder().decode(AppConfig.self, from: data)

        XCTAssertEqual(config.model, "saved-model")
        XCTAssertEqual(config.voiceInput, VoiceInputConfig.defaultConfig())
    }

    func testAppConfigRoundTripsVoiceInputConfig() throws {
        var config = AppConfig.defaultConfig()
        config.voiceInput = VoiceInputConfig(
            shortcut: .leftCommand,
            speechProviderID: "custom-speech",
            speechEndpoint: "https://speech.example.test/v1/audio/transcriptions",
            speechModel: "gpt-4o-transcribe",
            autoProcessTranscription: false,
            voiceCleanupPromptModeID: PromptMode.chineseSummaryID
        )

        let data = try JSONEncoder().encode(config)
        let decodedConfig = try JSONDecoder().decode(AppConfig.self, from: data)

        XCTAssertEqual(decodedConfig.voiceInput, config.voiceInput)
    }
}
