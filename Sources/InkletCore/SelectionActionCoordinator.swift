import Foundation

public struct SelectionPoint: Equatable, Sendable {
    public static let zero = SelectionPoint(x: 0, y: 0)

    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public enum SelectionActionEvent: Equatable, Sendable {
    case candidateSelection(sourceAppBundleID: String, mouseLocation: SelectionPoint)
    case readCompleted(SelectedTextReadResult)
    case dismiss
    case updateConfig(SelectionActionsConfig)
}

public enum SelectionActionEffect: Equatable, Sendable {
    case scheduleRead(delayMilliseconds: Int)
    case cancelRead
    case hidePanel
    case cancelWork
    case showPanel(text: String, location: SelectionPoint)
    case showUnsupportedNotice(appBundleID: String)
}

public struct SelectionActionCoordinator: Sendable {
    private var config: SelectionActionsConfig
    private let maxSelectionLength: Int
    private var pendingAppBundleID: String?
    private var pendingLocation: SelectionPoint = .zero
    private var unsupportedNoticeAppIDs = Set<String>()
    private var lastShownText: String?

    public init(
        config: SelectionActionsConfig,
        maxSelectionLength: Int = 4_000
    ) {
        self.config = config
        self.maxSelectionLength = maxSelectionLength
    }

    public mutating func handle(_ event: SelectionActionEvent) -> [SelectionActionEffect] {
        switch event {
        case .candidateSelection(let sourceAppBundleID, let mouseLocation):
            guard config.isEnabled else {
                pendingAppBundleID = nil
                return []
            }
            pendingAppBundleID = sourceAppBundleID
            pendingLocation = mouseLocation
            return [.scheduleRead(delayMilliseconds: 600)]

        case .readCompleted(let result):
            guard config.isEnabled, pendingAppBundleID != nil else {
                return []
            }
            pendingAppBundleID = nil

            switch result {
            case .success(let text):
                guard text.count <= maxSelectionLength, text != lastShownText else {
                    return []
                }
                lastShownText = text
                return [.showPanel(text: text, location: pendingLocation)]
            case .unsupported, .missingFocusedElement, .failed:
                return []
            case .permissionDenied, .emptySelection:
                return []
            }

        case .dismiss:
            pendingAppBundleID = nil
            return [.cancelRead, .hidePanel, .cancelWork]

        case .updateConfig(let config):
            self.config = config
            pendingAppBundleID = nil
            return config.isEnabled ? [] : [.cancelRead, .hidePanel, .cancelWork]
        }
    }
}
