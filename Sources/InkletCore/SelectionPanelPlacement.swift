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

public struct SelectionPanelRect: Equatable, Sendable {
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

    public func contains(_ point: SelectionPoint) -> Bool {
        point.x >= x
            && point.x <= x + width
            && point.y >= y
            && point.y <= y + height
    }
}

public enum SelectionPanelPlacement {
    public static func origin(
        forPanelSize panelSize: SelectionPanelSize,
        near anchor: SelectionPoint,
        in visibleFrame: SelectionScreenFrame,
        gap: Double = 18,
        margin: Double = 8
    ) -> SelectionPoint {
        let rightX = anchor.x + gap
        let leftX = anchor.x - panelSize.width - gap
        let preferredX = rightX + panelSize.width <= visibleFrame.maxX - margin ? rightX : leftX

        let aboveY = anchor.y + gap
        let belowY = anchor.y - panelSize.height - gap
        let preferredY = belowY >= visibleFrame.minY + margin ? belowY : aboveY

        return SelectionPoint(
            x: min(max(preferredX, visibleFrame.minX + margin), visibleFrame.maxX - panelSize.width - margin),
            y: min(max(preferredY, visibleFrame.minY + margin), visibleFrame.maxY - panelSize.height - margin)
        )
    }
}

public enum SelectionPanelSizing {
    /// The width is the one the user last dragged to, or grows with longer text. The height fits
    /// the content, measured at that width, between the minimum and the remembered height (or
    /// `defaultMaximumHeight`), so a one-line result is a short panel and a long one scrolls.
    public static func translationResultSize(
        textLength: Int,
        rememberedSize: SelectionPanelSize? = nil,
        minimumSize: SelectionPanelSize = SelectionPanelSize(width: 300, height: 72),
        maximumSize: SelectionPanelSize = SelectionPanelSize(width: 560, height: 520),
        defaultMaximumHeight: Double = 360,
        contentHeight: (Double) -> Double
    ) -> SelectionPanelSize {
        let preferredWidth: Double
        if let rememberedSize {
            preferredWidth = rememberedSize.width
        } else if textLength >= 900 {
            preferredWidth = 520
        } else if textLength >= 240 {
            preferredWidth = 440
        } else {
            preferredWidth = 320
        }

        let width = clamped(preferredWidth, minimum: minimumSize.width, maximum: maximumSize.width)
        let maximumHeight = clamped(
            rememberedSize?.height ?? defaultMaximumHeight,
            minimum: minimumSize.height,
            maximum: maximumSize.height
        )
        let height = clamped(contentHeight(width).rounded(.up), minimum: minimumSize.height, maximum: maximumHeight)
        return SelectionPanelSize(width: width, height: height)
    }

    public static func clamped(
        _ size: SelectionPanelSize,
        minimumSize: SelectionPanelSize,
        maximumSize: SelectionPanelSize
    ) -> SelectionPanelSize {
        SelectionPanelSize(
            width: clamped(size.width, minimum: minimumSize.width, maximum: maximumSize.width),
            height: clamped(size.height, minimum: minimumSize.height, maximum: maximumSize.height)
        )
    }

    private static func clamped(_ value: Double, minimum: Double, maximum: Double) -> Double {
        min(max(value, minimum), maximum)
    }
}

public struct SelectionPanelDragRegions: Equatable, Sendable {
    public let panelSize: SelectionPanelSize
    public let exclusionRects: [SelectionPanelRect]
    public let resizeEdgeWidth: Double

    public init(
        panelSize: SelectionPanelSize,
        exclusionRects: [SelectionPanelRect],
        resizeEdgeWidth: Double = 8
    ) {
        self.panelSize = panelSize
        self.exclusionRects = exclusionRects
        self.resizeEdgeWidth = resizeEdgeWidth
    }

    /// How far a press on the selection bar has to move before it drags the bar instead of clicking.
    public static let pressDragThreshold = 4.0

    public static func hasPassedPressDragThreshold(from start: SelectionPoint, to end: SelectionPoint) -> Bool {
        hypot(end.x - start.x, end.y - start.y) >= pressDragThreshold
    }

    public static func translationResultRegions(panelSize: SelectionPanelSize) -> SelectionPanelDragRegions {
        let padding = 4.0
        let toolbarHeight = 40.0
        let buttonHeight = 32.0
        let buttonY = 2.0
        let audioClusterWidth = min(180.0, max(120.0, panelSize.width * 0.42))

        return SelectionPanelDragRegions(
            panelSize: panelSize,
            exclusionRects: [
                SelectionPanelRect(
                    x: padding,
                    y: toolbarHeight,
                    width: max(0, panelSize.width - padding * 2),
                    height: max(0, panelSize.height - toolbarHeight - padding)
                ),
                SelectionPanelRect(x: padding, y: buttonY, width: 40, height: buttonHeight),
                SelectionPanelRect(
                    x: max(padding, panelSize.width - audioClusterWidth - padding),
                    y: buttonY,
                    width: audioClusterWidth,
                    height: buttonHeight
                )
            ]
        )
    }

    public func isBackgroundDragPoint(_ point: SelectionPoint) -> Bool {
        guard point.x > resizeEdgeWidth,
              point.y > resizeEdgeWidth,
              point.x < panelSize.width - resizeEdgeWidth,
              point.y < panelSize.height - resizeEdgeWidth
        else {
            return false
        }

        return !exclusionRects.contains { $0.contains(point) }
    }
}
