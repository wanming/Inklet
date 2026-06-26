import XCTest
@testable import InkletCore

final class SelectionAudioControlRoleTests: XCTestCase {
    func testAudioControlsUseDistinctLabelLocalizationKeys() {
        XCTAssertEqual(
            SelectionAudioControlRole.original.labelLocalizationKey,
            "selection.action.audioLabel.original"
        )
        XCTAssertEqual(
            SelectionAudioControlRole.translation.labelLocalizationKey,
            "selection.action.audioLabel.translation"
        )
    }

    func testAudioControlsUseFlatToolbarDisplayStyle() {
        XCTAssertEqual(SelectionAudioControlRole.original.displayStyle, .flatToolbarAction)
        XCTAssertEqual(SelectionAudioControlRole.translation.displayStyle, .flatToolbarAction)
    }

    func testFlatToolbarDisplayStyleUsesSubduedProminenceAndCompactIcons() {
        XCTAssertEqual(SelectionAudioControlDisplayStyle.flatToolbarAction.foregroundOpacity, 0.68)
        XCTAssertEqual(SelectionAudioControlDisplayStyle.flatToolbarAction.iconPointSize, 11)
    }
}
