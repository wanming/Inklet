import XCTest
@testable import InkletCore

final class ReleaseNotesMarkdownTests: XCTestCase {
    private let languages = ["English", "简体中文", "繁體中文", "日本語", "한국어", "Español", "Français", "Deutsch", "Português", "Italiano"]

    private let notes = """
    ## English
    - **Pronounce without an API key:** reads text offline.
    - **Try betas early:** turn on Beta updates.

    ## 简体中文
    - **不需要 API Key 也能发音**：离线朗读。

    ## Español
    - **Pronuncia sin clave de API**: sin conexión.

    ---
    macOS 14 or newer.

    **Full changelog:** https://github.com/wanming/Inklet/compare/v2.0.0-35...v2.1.0-36
    """

    func testSectionPicksThePreferredLanguageAndKeepsTheFooter() {
        XCTAssertEqual(
            InkletReleaseNotes.section(of: notes, preferring: ["简体中文", "English"], languageHeadings: languages),
            """
            - **不需要 API Key 也能发音**：离线朗读。

            macOS 14 or newer.

            **Full changelog:** https://github.com/wanming/Inklet/compare/v2.0.0-35...v2.1.0-36
            """
        )
    }

    func testSectionEndsTheLastLanguageAtTheFooterRule() {
        let section = InkletReleaseNotes.section(of: notes, preferring: ["espanol"], languageHeadings: languages)

        XCTAssertTrue(section.hasPrefix("- **Pronuncia sin clave de API**: sin conexión.\n\nmacOS 14 or newer."))
        XCTAssertFalse(section.contains("---"))
    }

    func testSectionFallsBackToEnglishThenToTheFirstLanguage() {
        let english = InkletReleaseNotes.section(of: notes, preferring: ["日本語", "English"], languageHeadings: languages)
        XCTAssertTrue(english.hasPrefix("- **Pronounce without an API key:** reads text offline.\n- **Try betas early:**"))
        XCTAssertFalse(english.contains("简体中文"))

        let first = InkletReleaseNotes.section(of: notes, preferring: ["Deutsch"], languageHeadings: languages)
        XCTAssertEqual(first, english)
    }

    func testSectionKeepsIntroductionAndLeavesNotesWithoutLanguageHeadingsUnchanged() {
        XCTAssertEqual(
            InkletReleaseNotes.section(
                of: "A security fix.\n\n## English\n- Fixed.\n\n## Deutsch\n- Behoben.",
                preferring: ["Deutsch"],
                languageHeadings: languages
            ),
            "A security fix.\n\n- Behoben."
        )

        let plain = "## Fixes\n- Faster dictation.\n\n---\nThanks!"
        XCTAssertEqual(
            InkletReleaseNotes.section(of: plain, preferring: ["English"], languageHeadings: languages),
            plain
        )
    }

    func testBlocksSplitHeadingsBulletsAndParagraphs() {
        XCTAssertEqual(
            InkletReleaseNotes.blocks("""
            ## What's new
            - **Bold** point
            * Second point
            +   Third point

            ---
            macOS 14 or newer.
            Second line.

            **Full changelog:** https://example.com
            #hashtag stays text
            -not a bullet
            """),
            [
                .heading("What's new"),
                .bullet("**Bold** point"),
                .bullet("Second point"),
                .bullet("Third point"),
                .paragraph("macOS 14 or newer.\nSecond line."),
                .paragraph("**Full changelog:** https://example.com\n#hashtag stays text\n-not a bullet"),
            ]
        )
        XCTAssertEqual(InkletReleaseNotes.blocks(" \n\n "), [])
    }
}
