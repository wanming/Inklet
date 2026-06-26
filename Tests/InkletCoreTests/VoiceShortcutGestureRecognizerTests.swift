import XCTest
@testable import InkletCore

final class VoiceShortcutGestureRecognizerTests: XCTestCase {
    func testTapToToggleTriggersOnCleanPressAndRelease() {
        var recognizer = VoiceShortcutGestureRecognizer()

        XCTAssertEqual(recognizer.pressBegan(at: 0, mode: .tapToToggle), [])
        XCTAssertEqual(recognizer.pressEnded(at: 0.08, mode: .tapToToggle), [.toggle])
    }

    func testTapToToggleIgnoresInterruptedPress() {
        var recognizer = VoiceShortcutGestureRecognizer()

        _ = recognizer.pressBegan(at: 0, mode: .tapToToggle)
        recognizer.interrupt()

        XCTAssertEqual(recognizer.pressEnded(at: 0.08, mode: .tapToToggle), [])
    }

    func testPressAndHoldStartsAfterDelayAndStopsOnRelease() {
        var recognizer = VoiceShortcutGestureRecognizer()

        XCTAssertEqual(recognizer.pressBegan(at: 0, mode: .pressAndHold), [])
        XCTAssertEqual(recognizer.holdDelayElapsed(at: 0.12, mode: .pressAndHold), [.start])
        XCTAssertEqual(recognizer.pressEnded(at: 0.4, mode: .pressAndHold), [.stop])
    }

    func testPressAndHoldDoesNotStartWhenReleasedBeforeDelay() {
        var recognizer = VoiceShortcutGestureRecognizer()

        _ = recognizer.pressBegan(at: 0, mode: .pressAndHold)

        XCTAssertEqual(recognizer.pressEnded(at: 0.04, mode: .pressAndHold), [])
        XCTAssertEqual(recognizer.holdDelayElapsed(at: 0.12, mode: .pressAndHold), [])
    }

    func testPressAndHoldStillStopsAfterInterruptOnceRecordingStarted() {
        var recognizer = VoiceShortcutGestureRecognizer()

        _ = recognizer.pressBegan(at: 0, mode: .pressAndHold)
        XCTAssertEqual(recognizer.holdDelayElapsed(at: 0.12, mode: .pressAndHold), [.start])
        recognizer.interrupt()

        XCTAssertEqual(recognizer.pressEnded(at: 0.4, mode: .pressAndHold), [.stop])
    }

    func testDoubleTapRequiresTwoCleanTapsWithinInterval() {
        var recognizer = VoiceShortcutGestureRecognizer(doubleTapInterval: 0.35)

        _ = recognizer.pressBegan(at: 0, mode: .doubleTap)
        XCTAssertEqual(recognizer.pressEnded(at: 0.04, mode: .doubleTap), [])
        _ = recognizer.pressBegan(at: 0.18, mode: .doubleTap)

        XCTAssertEqual(recognizer.pressEnded(at: 0.22, mode: .doubleTap), [.toggle])
    }

    func testDoubleTapIgnoresSlowSecondTap() {
        var recognizer = VoiceShortcutGestureRecognizer(doubleTapInterval: 0.35)

        _ = recognizer.pressBegan(at: 0, mode: .doubleTap)
        XCTAssertEqual(recognizer.pressEnded(at: 0.04, mode: .doubleTap), [])
        _ = recognizer.pressBegan(at: 0.5, mode: .doubleTap)

        XCTAssertEqual(recognizer.pressEnded(at: 0.54, mode: .doubleTap), [])
    }

    func testDoubleTapResetsWhenInterruptedBetweenTaps() {
        var recognizer = VoiceShortcutGestureRecognizer(doubleTapInterval: 0.35)

        _ = recognizer.pressBegan(at: 0, mode: .doubleTap)
        XCTAssertEqual(recognizer.pressEnded(at: 0.04, mode: .doubleTap), [])
        recognizer.interrupt()
        _ = recognizer.pressBegan(at: 0.18, mode: .doubleTap)

        XCTAssertEqual(recognizer.pressEnded(at: 0.22, mode: .doubleTap), [])
    }
}
