import XCTest
@testable import WritingPopoverCore

final class PopoverStateMachineTests: XCTestCase {
    func testInitialStateIsClosed() {
        let machine = PopoverStateMachine()
        XCTAssertEqual(machine.state, .closed)
    }
}
