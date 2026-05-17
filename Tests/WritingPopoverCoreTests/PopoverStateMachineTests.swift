import XCTest
@testable import WritingPopoverCore

final class PopoverStateMachineTests: XCTestCase {
    func testOpeningPopoverStartsEditingWithEmptySource() {
        let machine = PopoverStateMachine()

        let actions = machine.send(.open)

        XCTAssertEqual(machine.state, .editingSource(source: "", errorMessage: nil))
        XCTAssertEqual(actions, [.focusSourceInput])
    }

    func testSubmittingSourceStartsTransformation() {
        let machine = PopoverStateMachine(state: .editingSource(source: "帮我写封英文邮件", errorMessage: nil))

        let actions = machine.send(.submit)

        XCTAssertEqual(machine.state, .transforming(source: "帮我写封英文邮件"))
        XCTAssertEqual(actions, [.startTransformation(source: "帮我写封英文邮件")])
    }

    func testSuccessfulTransformationShowsPreview() {
        let machine = PopoverStateMachine(state: .transforming(source: "i has a apple"))

        let actions = machine.send(.transformationSucceeded(result: "I have an apple."))

        XCTAssertEqual(machine.state, .previewingResult(source: "i has a apple", result: "I have an apple."))
        XCTAssertEqual(actions, [.showResult("I have an apple.")])
    }

    func testSecondEnterInsertsResult() {
        let machine = PopoverStateMachine(state: .previewingResult(source: "hi", result: "Hello."))

        let actions = machine.send(.submit)

        XCTAssertEqual(machine.state, .inserting(text: "Hello."))
        XCTAssertEqual(actions, [.insertText("Hello.")])
    }

    func testEscapeRejectsPreviewAndReturnsToSource() {
        let machine = PopoverStateMachine(state: .previewingResult(source: "hi", result: "Hello."))

        let actions = machine.send(.escape)

        XCTAssertEqual(machine.state, .editingSource(source: "hi", errorMessage: nil))
        XCTAssertEqual(actions, [.focusSourceInput])
    }

    func testCommandEnterInsertsOriginalSource() {
        let machine = PopoverStateMachine(state: .editingSource(source: "原文", errorMessage: nil))

        let actions = machine.send(.insertOriginal)

        XCTAssertEqual(machine.state, .inserting(text: "原文"))
        XCTAssertEqual(actions, [.insertText("原文")])
    }

    func testFailureKeepsSourceAndShowsInlineError() {
        let machine = PopoverStateMachine(state: .transforming(source: "source"))

        let actions = machine.send(.transformationFailed(message: "网络失败"))

        XCTAssertEqual(machine.state, .editingSource(source: "source", errorMessage: "网络失败"))
        XCTAssertEqual(actions, [.showError("网络失败"), .focusSourceInput])
    }

    func testCloseResetsState() {
        let machine = PopoverStateMachine(state: .editingSource(source: "draft", errorMessage: nil))

        let actions = machine.send(.close)

        XCTAssertEqual(machine.state, .closed)
        XCTAssertEqual(actions, [.hidePopover])
    }
}
