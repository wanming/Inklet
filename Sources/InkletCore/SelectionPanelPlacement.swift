import Foundation

public struct SelectionPanelSize: Equatable, Sendable {
    public let width: Double
    public let height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public struct SelectionScreenFrame: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    var minX: Double { x }
    var minY: Double { y }
    var maxX: Double { x + width }
    var maxY: Double { y + height }
}

public enum SelectionPanelPlacement {
    public static func origin(
        forPanelSize panelSize: SelectionPanelSize,
        near anchor: SelectionPoint,
        in visibleFrame: SelectionScreenFrame,
        gap: Double = 12,
        margin: Double = 8
    ) -> SelectionPoint {
        let rightX = anchor.x + gap
        let leftX = anchor.x - panelSize.width - gap
        let preferredX = rightX + panelSize.width <= visibleFrame.maxX - margin ? rightX : leftX

        let aboveY = anchor.y + gap
        let belowY = anchor.y - panelSize.height - gap
        let preferredY = aboveY + panelSize.height <= visibleFrame.maxY - margin ? aboveY : belowY

        return SelectionPoint(
            x: min(max(preferredX, visibleFrame.minX + margin), visibleFrame.maxX - panelSize.width - margin),
            y: min(max(preferredY, visibleFrame.minY + margin), visibleFrame.maxY - panelSize.height - margin)
        )
    }
}
