import Foundation

public enum SelectionAudioControlRole: Equatable, Sendable {
    case original
    case translation

    public var labelLocalizationKey: String {
        switch self {
        case .original:
            "selection.action.audioLabel.original"
        case .translation:
            "selection.action.audioLabel.translation"
        }
    }

    public var displayStyle: SelectionAudioControlDisplayStyle {
        .flatToolbarAction
    }
}

public enum SelectionAudioControlDisplayStyle: Equatable, Sendable {
    case flatToolbarAction

    public var foregroundOpacity: Double {
        switch self {
        case .flatToolbarAction:
            0.68
        }
    }

    public var iconPointSize: Int {
        switch self {
        case .flatToolbarAction:
            11
        }
    }
}
