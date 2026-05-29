import Foundation

public final class PopoverStateMachine {
    public enum State: Equatable {
        case closed
        case editingSource(source: String, errorMessage: String?)
        case transforming(source: String)
        case previewingResult(source: String, result: String)
        case inserting(text: String)
    }

    public enum Event: Equatable {
        case open
        case sourceChanged(String)
        case resultChanged(String)
        case submit
        case insertOriginal
        case transformationSucceeded(result: String)
        case transformationFailed(message: String)
        case escape
        case close
        case insertionFinished
    }

    public enum Action: Equatable {
        case showPopover
        case hidePopover
        case focusSourceInput
        case startTransformation(source: String)
        case showResult(String)
        case showError(String)
        case insertText(String)
    }

    public private(set) var state: State

    public init(state: State = .closed) {
        self.state = state
    }

    @discardableResult
    public func send(_ event: Event) -> [Action] {
        switch (state, event) {
        case (.closed, .open):
            state = .editingSource(source: "", errorMessage: nil)
            return [.focusSourceInput]

        case (.editingSource(_, _), .sourceChanged(let source)):
            state = .editingSource(source: source, errorMessage: nil)
            return []

        case (.previewingResult, .sourceChanged(let source)):
            state = .editingSource(source: source, errorMessage: nil)
            return []

        case (.previewingResult(let source, _), .resultChanged(let result)):
            state = .previewingResult(source: source, result: result)
            return []

        case (.editingSource(let source, _), .submit):
            let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                state = .editingSource(source: source, errorMessage: "请输入要转换的文本")
                return [.showError("请输入要转换的文本"), .focusSourceInput]
            }
            state = .transforming(source: source)
            return [.startTransformation(source: source)]

        case (.editingSource(let source, _), .insertOriginal):
            state = .inserting(text: source)
            return [.insertText(source)]

        case (.transforming(let source), .transformationSucceeded(let result)):
            state = .previewingResult(source: source, result: result)
            return [.showResult(result)]

        case (.transforming(let source), .transformationFailed(let message)):
            state = .editingSource(source: source, errorMessage: message)
            return [.showError(message), .focusSourceInput]

        case (.transforming, .escape):
            state = .closed
            return [.hidePopover]

        case (.previewingResult, .escape):
            state = .closed
            return [.hidePopover]

        case (.previewingResult(_, let result), .submit):
            state = .inserting(text: result)
            return [.insertText(result)]

        case (_, .close):
            state = .closed
            return [.hidePopover]

        case (.inserting, .insertionFinished):
            state = .closed
            return [.hidePopover]

        default:
            return []
        }
    }
}
