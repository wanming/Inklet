import XCTest
@testable import InkletCore

final class VoiceInputCancellationPolicyTests: XCTestCase {
    func testEscapeCancelsOnlyWhileVoiceInputIsActive() {
        XCTAssertTrue(VoiceInputCancellationPolicy.shouldCancel(
            keyCode: 53,
            isVoiceInputActive: true
        ))
        XCTAssertFalse(VoiceInputCancellationPolicy.shouldCancel(
            keyCode: 53,
            isVoiceInputActive: false
        ))
        XCTAssertFalse(VoiceInputCancellationPolicy.shouldCancel(
            keyCode: 36,
            isVoiceInputActive: true
        ))
    }
}
