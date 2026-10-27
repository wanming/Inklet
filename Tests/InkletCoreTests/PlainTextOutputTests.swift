import XCTest
@testable import InkletCore

final class PlainTextOutputTests: XCTestCase {
    func testStripsMarkdownWhenSourceIsPlainText() {
        let output = """
        ## Summary
        The **launch** moves to *Friday*.
        - Ship the `beta` build
        * Email the team
        ---
        > Quoted note
        See [the plan](https://example.com/plan) or [https://example.com](https://example.com).
        """

        XCTAssertEqual(clean(output, source: "The launch moves to Friday, ship beta, email team."), """
        Summary
        The launch moves to Friday.
        • Ship the beta build
        • Email the team
        Quoted note
        See the plan (https://example.com/plan) or https://example.com.
        """)
    }

    func testStripsCodeFenceAroundWholeResult() {
        let output = """
        ```text
        Hello, world.
        ```
        """

        XCTAssertEqual(clean(output, source: "hello world").trimmingCharacters(in: .newlines), "Hello, world.")
    }

    func testLeavesFencedCodeContentAlone() {
        let output = """
        Run this:
        ```
        rm *.tmp *.log
        - not a bullet
        ```
        """

        XCTAssertEqual(clean(output, source: "run this to delete temp files"), """
        Run this:
        rm *.tmp *.log
        - not a bullet
        """)
    }

    func testDictionaryEntryBecomesPlainLines() {
        let output = """
        **serendipity** /ˌserənˈdɪpəti/ *n.*
        1. 意外发现珍奇事物的运气
        **例句：** *Finding this café was pure serendipity.*
        """

        XCTAssertEqual(clean(output, source: "serendipity"), """
        serendipity /ˌserənˈdɪpəti/ n.
        1. 意外发现珍奇事物的运气
        例句： Finding this café was pure serendipity.
        """)
    }

    func testKeepsMarkdownTheSourceAlreadyUses() {
        let source = """
        # Release notes
        - fixed **crash** on launch
        """
        let output = """
        # Release notes
        - Fixed a **crash** at launch.
        Use `inklet --reset` *carefully*.
        """

        XCTAssertEqual(clean(output, source: source), """
        # Release notes
        - Fixed a **crash** at launch.
        Use inklet --reset carefully.
        """)
    }

    func testLeavesPlainTextSymbolsAlone() {
        let output = """
        2*3*4 = 24, file_name_here, C# and F#, 5 * 6.
        #hashtag
        1. First step
        """

        XCTAssertEqual(clean(output, source: "math"), output)
    }

    func testPromptThatAsksForMarkdownKeepsEverything() {
        let output = "## Title\n- **Point**"

        XCTAssertEqual(
            PlainTextOutput.clean(output, sourceText: "notes", systemPrompt: "Format the notes as a Markdown list."),
            output
        )
        XCTAssertEqual(
            PlainTextOutput.clean(output, sourceText: "notes", systemPrompt: "用 Markdown 列表整理"),
            output
        )
    }

    func testBuiltInPromptsDoNotCountAsAskingForMarkdown() {
        let prompts = PromptModeStore.defaultStore().modes.map(\.systemPrompt) + [
            SelectionActionsConfig.defaultTranslationPrompt
        ]

        for prompt in prompts {
            XCTAssertFalse(PlainTextOutput.promptRequestsMarkdown(prompt), prompt)
        }
    }

    func testSystemPromptAsksForPlainTextOnlyWhenSourceHasNoMarkdown() {
        XCTAssertEqual(
            PlainTextOutput.systemPrompt("Translate.", sourceText: "Hello there"),
            "Translate.\n" + PlainTextOutput.promptInstruction
        )
        XCTAssertEqual(PlainTextOutput.systemPrompt("Translate.", sourceText: "- **Hello** there"), "Translate.")
        XCTAssertEqual(
            PlainTextOutput.systemPrompt("Answer in Markdown.", sourceText: "Hello there"),
            "Answer in Markdown."
        )
    }

    private func clean(_ output: String, source: String) -> String {
        PlainTextOutput.clean(output, sourceText: source, systemPrompt: "Translate the text.")
    }
}
