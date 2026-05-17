public final class PopoverStateMachine {
    public enum State: Equatable {
        case closed
    }

    public private(set) var state: State

    public init(state: State = .closed) {
        self.state = state
    }
}
