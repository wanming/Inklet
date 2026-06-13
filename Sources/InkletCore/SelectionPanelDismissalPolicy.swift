import Foundation

public struct SelectionPanelDismissalPolicy: Equatable, Sendable {
    private let graceInterval: TimeInterval
    private var visibleUntil: TimeInterval?

    public init(graceInterval: TimeInterval = 3) {
        self.graceInterval = graceInterval
    }

    public mutating func recordPanelShown(at time: TimeInterval) {
        visibleUntil = time + graceInterval
    }

    public func shouldDismiss(at time: TimeInterval) -> Bool {
        guard let visibleUntil else {
            return true
        }

        return time >= visibleUntil
    }
}
