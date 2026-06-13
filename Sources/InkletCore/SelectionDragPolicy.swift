import Foundation

public struct SelectionDragPolicy: Equatable, Sendable {
    private let minimumDistance: Double
    private var startPoint: SelectionPoint?

    public init(minimumDistance: Double = 6) {
        self.minimumDistance = minimumDistance
    }

    public mutating func recordMouseDown(at point: SelectionPoint) {
        startPoint = point
    }

    public mutating func consumeMouseUp(at point: SelectionPoint) -> Bool {
        defer {
            startPoint = nil
        }

        guard let startPoint else {
            return false
        }

        let dx = point.x - startPoint.x
        let dy = point.y - startPoint.y
        return (dx * dx + dy * dy).squareRoot() >= minimumDistance
    }
}
