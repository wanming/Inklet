import XCTest
@testable import InkletCore

final class SystemSpeechVoicePickerTests: XCTestCase {
    private typealias Voice = SystemSpeechVoicePicker.Voice

    func testDetectsTheLanguageTheTextIsWrittenIn() {
        let preferred = ["en-US"]

        XCTAssertEqual(SystemSpeechVoicePicker.language(of: "This is a short test sentence.", preferredLanguageCodes: preferred), "en")
        XCTAssertEqual(SystemSpeechVoicePicker.language(of: "这是一个用来测试发音的句子。", preferredLanguageCodes: preferred), "zh-Hans")
        XCTAssertEqual(SystemSpeechVoicePicker.language(of: "這是一個用來測試發音的句子。", preferredLanguageCodes: preferred), "zh-Hant")
        XCTAssertEqual(SystemSpeechVoicePicker.language(of: "これは発音をテストするための文です。", preferredLanguageCodes: preferred), "ja")
    }

    func testFallsBackToThePreferredLanguageWhenNothingIsDetected() {
        XCTAssertEqual(SystemSpeechVoicePicker.language(of: "123", preferredLanguageCodes: ["de-DE"]), "de")
    }

    func testMapsLocaleIdentifiersToTextLanguages() {
        XCTAssertEqual(SystemSpeechVoicePicker.textLanguage(ofLocaleIdentifier: "zh-Hans-CN"), "zh-Hans")
        XCTAssertEqual(SystemSpeechVoicePicker.textLanguage(ofLocaleIdentifier: "zh-Hant"), "zh-Hant")
        XCTAssertEqual(SystemSpeechVoicePicker.textLanguage(ofLocaleIdentifier: "zh-TW"), "zh-Hant")
        XCTAssertEqual(SystemSpeechVoicePicker.textLanguage(ofLocaleIdentifier: "zh-CN"), "zh-Hans")
        XCTAssertEqual(SystemSpeechVoicePicker.textLanguage(ofLocaleIdentifier: "en-GB"), "en")
        XCTAssertEqual(SystemSpeechVoicePicker.textLanguage(ofLocaleIdentifier: "pt-BR"), "pt")
    }

    func testPrefersThePersonsOwnRegionThenTheUsualRegionThenQuality() {
        let voices = [
            Voice(identifier: "gb", language: "en-GB", quality: .default),
            Voice(identifier: "us", language: "en-US", quality: .default),
            Voice(identifier: "us-premium", language: "en-US", quality: .premium),
            Voice(identifier: "au-premium", language: "en-AU", quality: .premium),
            Voice(identifier: "zh", language: "zh-CN", quality: .enhanced),
        ]

        XCTAssertEqual(
            SystemSpeechVoicePicker.bestVoice(for: "en", among: voices, preferredLanguageCodes: ["zh-Hans-CN"])?.identifier,
            "us-premium"
        )
        XCTAssertEqual(
            SystemSpeechVoicePicker.bestVoice(for: "en", among: voices, preferredLanguageCodes: ["en-GB"])?.identifier,
            "gb"
        )
        XCTAssertNil(SystemSpeechVoicePicker.bestVoice(for: "ko", among: voices, preferredLanguageCodes: ["en-US"]))
    }

    func testReadsChineseInMandarinUnlessThePersonIsInHongKong() {
        let voices = [
            Voice(identifier: "hk", language: "zh-HK", quality: .premium),
            Voice(identifier: "tw", language: "zh-TW", quality: .default),
            Voice(identifier: "cn", language: "zh-CN", quality: .default),
        ]

        XCTAssertEqual(
            SystemSpeechVoicePicker.bestVoice(for: "zh-Hans", among: voices, preferredLanguageCodes: ["en-US"])?.identifier,
            "cn"
        )
        XCTAssertEqual(
            SystemSpeechVoicePicker.bestVoice(for: "zh-Hant", among: voices, preferredLanguageCodes: ["en-US"])?.identifier,
            "tw"
        )
        XCTAssertEqual(
            SystemSpeechVoicePicker.bestVoice(for: "zh-Hant", among: voices, preferredLanguageCodes: ["zh-Hant-HK"])?.identifier,
            "hk"
        )
        XCTAssertEqual(
            SystemSpeechVoicePicker.bestVoice(
                for: "zh-Hant",
                among: [voices[0], voices[2]],
                preferredLanguageCodes: ["en-US"]
            )?.identifier,
            "cn"
        )
    }

    func testSkipsExcludedVoices() {
        let voices = [
            Voice(identifier: "novelty", language: "en-US", quality: .premium, isExcluded: true),
            Voice(identifier: "plain", language: "en-US", quality: .default),
        ]

        XCTAssertEqual(
            SystemSpeechVoicePicker.bestVoice(for: "en", among: voices, preferredLanguageCodes: [])?.identifier,
            "plain"
        )
    }

    func testRateScalesTheSystemDefaultWithinItsLimits() {
        XCTAssertEqual(SystemSpeechVoicePicker.rate(forSpeed: 1, defaultRate: 0.5, minimumRate: 0, maximumRate: 1), 0.5)
        XCTAssertEqual(SystemSpeechVoicePicker.rate(forSpeed: 1.5, defaultRate: 0.5, minimumRate: 0, maximumRate: 1), 0.75)
        XCTAssertEqual(SystemSpeechVoicePicker.rate(forSpeed: 3, defaultRate: 0.5, minimumRate: 0, maximumRate: 1), 1)
    }
}
