import XCTest
@testable import InkletCore

final class SelectionActionCoordinatorTests: XCTestCase {
    func testCandidateEventSchedulesReadWhenEnabled() {
        var coordinator = SelectionActionCoordinator(config: .defaultConfig())

        let actions = coordinator.handle(.candidateSelection(sourceAppBundleID: "com.apple.TextEdit", mouseLocation: .zero))

        XCTAssertEqual(actions, [.scheduleRead(delayMilliseconds: 600)])
    }

    func testDisabledConfigIgnoresCandidateEvents() {
        var coordinator = SelectionActionCoordinator(config: SelectionActionsConfig(isEnabled: false))

        let actions = coordinator.handle(.candidateSelection(sourceAppBundleID: "com.apple.TextEdit", mouseLocation: .zero))

        XCTAssertEqual(actions, [])
    }

    func testDismissalCancelsPendingReadAndHidesPanel() {
        var coordinator = SelectionActionCoordinator(config: .defaultConfig())
        _ = coordinator.handle(.candidateSelection(sourceAppBundleID: "com.apple.TextEdit", mouseLocation: .zero))

        let actions = coordinator.handle(.dismiss)

        XCTAssertEqual(actions, [.cancelRead, .hidePanel, .cancelWork])
    }

    func testSuccessfulReadShowsPanel() {
        var coordinator = SelectionActionCoordinator(config: .defaultConfig())
        _ = coordinator.handle(.candidateSelection(
            sourceAppBundleID: "com.apple.TextEdit",
            mouseLocation: SelectionPoint(x: 10, y: 20)
        ))

        let actions = coordinator.handle(.readCompleted(.success("hello")))

        XCTAssertEqual(actions, [.showPanel(text: "hello", location: SelectionPoint(x: 10, y: 20))])
    }

    func testRepeatedTextDoesNotShowPanelAgain() {
        var coordinator = SelectionActionCoordinator(config: .defaultConfig())
        _ = coordinator.handle(.candidateSelection(sourceAppBundleID: "com.apple.TextEdit", mouseLocation: .zero))
        _ = coordinator.handle(.readCompleted(.success("hello")))
        _ = coordinator.handle(.dismiss)
        _ = coordinator.handle(.candidateSelection(sourceAppBundleID: "com.apple.TextEdit", mouseLocation: .zero))

        let actions = coordinator.handle(.readCompleted(.success("hello")))

        XCTAssertEqual(actions, [])
    }

    func testUnsupportedReadIsIgnoredForPassiveSelection() {
        var coordinator = SelectionActionCoordinator(config: .defaultConfig())
        _ = coordinator.handle(.candidateSelection(sourceAppBundleID: "com.apple.TextEdit", mouseLocation: .zero))

        XCTAssertEqual(coordinator.handle(.readCompleted(.unsupported)), [])
    }

    func testTooLongSelectionIsIgnored() {
        var coordinator = SelectionActionCoordinator(config: .defaultConfig(), maxSelectionLength: 5)
        _ = coordinator.handle(.candidateSelection(sourceAppBundleID: "com.apple.TextEdit", mouseLocation: .zero))

        let actions = coordinator.handle(.readCompleted(.success("too long")))

        XCTAssertEqual(actions, [])
    }
}
