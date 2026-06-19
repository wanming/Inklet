import XCTest
@testable import InkletCore

final class SpeakerWaveIconSequenceTests: XCTestCase {
    func testKeepsSpeakerSymbolStableWhilePlaying() {
        XCTAssertEqual(SpeakerWaveIconSequence.systemImageName(forFrame: 0), "speaker")
        XCTAssertEqual(SpeakerWaveIconSequence.systemImageName(forFrame: 1), "speaker")
        XCTAssertEqual(SpeakerWaveIconSequence.systemImageName(forFrame: 2), "speaker")
        XCTAssertEqual(SpeakerWaveIconSequence.systemImageName(forFrame: 3), "speaker")
        XCTAssertEqual(SpeakerWaveIconSequence.systemImageName(forFrame: 4), "speaker")
    }

    func testMapsElapsedTimeToStableFrames() {
        let duration = SpeakerWaveIconSequence.frameDuration

        XCTAssertEqual(SpeakerWaveIconSequence.systemImageName(atElapsedTime: 0), "speaker")
        XCTAssertEqual(SpeakerWaveIconSequence.systemImageName(atElapsedTime: duration), "speaker")
        XCTAssertEqual(SpeakerWaveIconSequence.systemImageName(atElapsedTime: duration * 2), "speaker")
        XCTAssertEqual(SpeakerWaveIconSequence.systemImageName(atElapsedTime: duration * 3), "speaker")
        XCTAssertEqual(SpeakerWaveIconSequence.systemImageName(atElapsedTime: duration * 4), "speaker")
    }

    func testCyclesVisibleBracketCounts() {
        XCTAssertEqual(SpeakerWaveIconSequence.bracketCount(forFrame: 0), 1)
        XCTAssertEqual(SpeakerWaveIconSequence.bracketCount(forFrame: 1), 2)
        XCTAssertEqual(SpeakerWaveIconSequence.bracketCount(forFrame: 2), 3)
        XCTAssertEqual(SpeakerWaveIconSequence.bracketCount(forFrame: 3), 2)
        XCTAssertEqual(SpeakerWaveIconSequence.bracketCount(forFrame: 4), 1)
    }

    func testIdleBracketCountUsesMiddlePlaybackFrame() {
        XCTAssertEqual(SpeakerWaveIconSequence.idleBracketCount, 2)
    }

    func testMapsElapsedTimeToBracketCounts() {
        let duration = SpeakerWaveIconSequence.frameDuration

        XCTAssertEqual(SpeakerWaveIconSequence.bracketCount(atElapsedTime: 0), 1)
        XCTAssertEqual(SpeakerWaveIconSequence.bracketCount(atElapsedTime: duration), 2)
        XCTAssertEqual(SpeakerWaveIconSequence.bracketCount(atElapsedTime: duration * 2), 3)
        XCTAssertEqual(SpeakerWaveIconSequence.bracketCount(atElapsedTime: duration * 3), 2)
        XCTAssertEqual(SpeakerWaveIconSequence.bracketCount(atElapsedTime: duration * 4), 1)
    }
}
