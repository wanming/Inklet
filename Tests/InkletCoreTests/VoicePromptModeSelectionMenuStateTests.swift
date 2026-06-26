import XCTest
@testable import InkletCore

final class VoicePromptModeSelectionMenuStateTests: XCTestCase {
    func testMovesSelectionWithArrowKeysAndClampsToAvailableRows() {
        var state = VoicePromptModeSelectionMenuState(selections: [
            .promptMode(PromptMode.voiceCleanupID),
            .promptMode(PromptMode.chineseSummaryID),
            .rawTranscript
        ])

        XCTAssertEqual(state.selectedIndex, 0)
        XCTAssertEqual(state.selectedSelection, .promptMode(PromptMode.voiceCleanupID))

        state.moveSelectionDown()
        XCTAssertEqual(state.selectedIndex, 1)
        XCTAssertEqual(state.selectedSelection, .promptMode(PromptMode.chineseSummaryID))

        state.moveSelectionDown()
        state.moveSelectionDown()
        XCTAssertEqual(state.selectedIndex, 2)
        XCTAssertEqual(state.selectedSelection, .rawTranscript)

        state.moveSelectionUp()
        XCTAssertEqual(state.selectedIndex, 1)

        state.moveSelectionUp()
        state.moveSelectionUp()
        XCTAssertEqual(state.selectedIndex, 0)
    }

    func testSelectingRowUpdatesSelectedSelection() {
        var state = VoicePromptModeSelectionMenuState(selections: [
            .promptMode(PromptMode.voiceCleanupID),
            .rawTranscript
        ])

        XCTAssertEqual(state.select(index: 1), .rawTranscript)
        XCTAssertEqual(state.selectedIndex, 1)
        XCTAssertEqual(state.selectedSelection, .rawTranscript)

        XCTAssertNil(state.select(index: 12))
        XCTAssertEqual(state.selectedIndex, 1)
    }

    func testEmptyMenuHasNoSelectedSelection() {
        var state = VoicePromptModeSelectionMenuState(selections: [])

        XCTAssertNil(state.selectedSelection)
        state.moveSelectionDown()
        XCTAssertNil(state.select(index: 0))
        XCTAssertEqual(state.selectedIndex, 0)
    }
}
