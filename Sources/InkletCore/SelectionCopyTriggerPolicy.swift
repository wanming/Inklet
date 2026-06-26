import Foundation

public struct SelectionCopyTriggerPolicy: Equatable, Sendable {
    private let doubleCopyInterval: TimeInterval
    private var lastCopyTime: TimeInterval?

    public init(doubleCopyInterval: TimeInterval = 0.8) {
        self.doubleCopyInterval = doubleCopyInterval
    }

    public mutating func recordCopy(at time: TimeInterval) -> Bool {
        defer {
            lastCopyTime = time
        }

        guard let lastCopyTime else {
            return false
        }

        return time - lastCopyTime <= doubleCopyInterval
    }
}
