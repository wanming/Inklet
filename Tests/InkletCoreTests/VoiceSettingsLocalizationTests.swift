import XCTest

final class VoiceSettingsLocalizationTests: XCTestCase {
    func testPostTranscriptionDefaultActionCopyMatchesCleanupModeLabel() throws {
        let packageRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let localizationURL = packageRoot.appendingPathComponent("Sources/InkletApp/InkletLocalization.swift")
        let source = try String(contentsOf: localizationURL, encoding: .utf8)

        XCTAssertTrue(source.contains(#""settings.voicePostTranscription.useDefaultPromptMode": "Use Cleanup Mode""#))
        XCTAssertTrue(source.contains("uses the cleanup mode below"))
        XCTAssertFalse(source.contains("Use Default Mode"))
    }
}
