import XCTest
@testable import InkletCore

final class SelectionActionsConfigTests: XCTestCase {
    func testDefaultConfigIsEnabledAndFollowsInterfaceLanguage() {
        let config = SelectionActionsConfig.defaultConfig()

        XCTAssertTrue(config.isEnabled)
        XCTAssertEqual(config.translationLanguage, .followInterfaceLanguage)
    }

    func testTranslationLanguagePromptNames() {
        XCTAssertEqual(SelectionTranslationLanguage.english.promptTargetName, "English")
        XCTAssertEqual(SelectionTranslationLanguage.simplifiedChinese.promptTargetName, "Simplified Chinese")
        XCTAssertEqual(SelectionTranslationLanguage.traditionalChinese.promptTargetName, "Traditional Chinese")
        XCTAssertEqual(SelectionTranslationLanguage.japanese.promptTargetName, "Japanese")
        XCTAssertEqual(SelectionTranslationLanguage.korean.promptTargetName, "Korean")
        XCTAssertEqual(SelectionTranslationLanguage.spanish.promptTargetName, "Spanish")
        XCTAssertEqual(SelectionTranslationLanguage.french.promptTargetName, "French")
        XCTAssertEqual(SelectionTranslationLanguage.german.promptTargetName, "German")
        XCTAssertEqual(SelectionTranslationLanguage.portuguese.promptTargetName, "Portuguese")
        XCTAssertEqual(SelectionTranslationLanguage.italian.promptTargetName, "Italian")
    }

    func testFollowInterfaceLanguageResolvesSupportedLanguages() {
        XCTAssertEqual(
            SelectionTranslationLanguage.followInterfaceLanguage.resolvedPromptTargetName(interfaceLanguageCode: "zh-Hans"),
            "Simplified Chinese"
        )
        XCTAssertEqual(
            SelectionTranslationLanguage.followInterfaceLanguage.resolvedPromptTargetName(interfaceLanguageCode: "zh-Hant"),
            "Traditional Chinese"
        )
        XCTAssertEqual(
            SelectionTranslationLanguage.followInterfaceLanguage.resolvedPromptTargetName(interfaceLanguageCode: "ja"),
            "Japanese"
        )
        XCTAssertEqual(
            SelectionTranslationLanguage.followInterfaceLanguage.resolvedPromptTargetName(interfaceLanguageCode: "ko"),
            "Korean"
        )
        XCTAssertEqual(
            SelectionTranslationLanguage.followInterfaceLanguage.resolvedPromptTargetName(interfaceLanguageCode: "es"),
            "Spanish"
        )
        XCTAssertEqual(
            SelectionTranslationLanguage.followInterfaceLanguage.resolvedPromptTargetName(interfaceLanguageCode: "fr"),
            "French"
        )
        XCTAssertEqual(
            SelectionTranslationLanguage.followInterfaceLanguage.resolvedPromptTargetName(interfaceLanguageCode: "de"),
            "German"
        )
        XCTAssertEqual(
            SelectionTranslationLanguage.followInterfaceLanguage.resolvedPromptTargetName(interfaceLanguageCode: "pt"),
            "Portuguese"
        )
        XCTAssertEqual(
            SelectionTranslationLanguage.followInterfaceLanguage.resolvedPromptTargetName(interfaceLanguageCode: "it"),
            "Italian"
        )
    }

    func testFollowInterfaceLanguageFallsBackToEnglish() {
        XCTAssertEqual(
            SelectionTranslationLanguage.followInterfaceLanguage.resolvedPromptTargetName(interfaceLanguageCode: "unknown"),
            "English"
        )
    }
}
