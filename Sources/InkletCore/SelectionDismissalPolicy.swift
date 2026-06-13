import Foundation

public struct SelectionDismissalPolicy: Equatable, Sendable {
    private let candidateGraceInterval: TimeInterval
    private var lastCandidateTime: TimeInterval?

    public init(candidateGraceInterval: TimeInterval = 0.9) {
        self.candidateGraceInterval = candidateGraceInterval
    }

    public mutating func recordCandidate(at time: TimeInterval) {
        lastCandidateTime = time
    }

    public func shouldDismiss(at time: TimeInterval) -> Bool {
        guard let lastCandidateTime else {
            return true
        }

        return time - lastCandidateTime >= candidateGraceInterval
    }
}
