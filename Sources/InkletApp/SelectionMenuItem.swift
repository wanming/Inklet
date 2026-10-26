import InkletCore

/// A button in the selection menu, ready to display.
struct SelectionMenuItem: Equatable, Identifiable {
    static let defaults = [
        SelectionMenuItem(action: .translate),
        SelectionMenuItem(action: .pronounce)
    ]

    let action: SelectionMenuAction
    var promptModeName: String?

    var id: String { action.storageID }

    var title: String {
        switch action {
        case .translate:
            L10n.text("selection.action.translate")
        case .pronounce:
            L10n.text("selection.action.pronounce")
        case .promptMode:
            promptModeName ?? ""
        }
    }

    var systemImage: String {
        switch action {
        case .translate:
            "character.bubble"
        case .pronounce:
            "speaker.wave.2"
        case .promptMode:
            "wand.and.stars"
        }
    }

    static func items(for buttons: [SelectionMenuButton], promptModes: [PromptMode], languages: PromptLanguages) -> [SelectionMenuItem] {
        buttons.map { button in
            guard case .promptMode(let modeID) = button.action else {
                return SelectionMenuItem(action: button.action)
            }
            let name = promptModes.first { $0.id == modeID }?.displayName(languages: languages)
            return SelectionMenuItem(action: button.action, promptModeName: name)
        }
    }

    static func enabledItems(for config: AppConfig) -> [SelectionMenuItem] {
        items(
            for: config.selectionActions.enabledMenuButtons(promptModes: config.promptModes),
            promptModes: config.promptModes,
            languages: config.promptLanguages
        )
    }
}

/// What the result panel is showing, so its labels match.
enum SelectionActionResultKind: Equatable {
    case translation
    case promptMode
}
