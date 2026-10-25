import Foundation

/// An action the selection menu can offer as a button.
public enum SelectionMenuAction: Hashable, Sendable {
    case translate
    case pronounce
    case promptMode(String)

    private static let promptModePrefix = "mode:"

    public init?(storageID: String) {
        switch storageID {
        case "translate":
            self = .translate
        case "pronounce":
            self = .pronounce
        default:
            guard storageID.hasPrefix(Self.promptModePrefix) else {
                return nil
            }
            let modeID = String(storageID.dropFirst(Self.promptModePrefix.count))
            guard !modeID.isEmpty else {
                return nil
            }
            self = .promptMode(modeID)
        }
    }

    public var storageID: String {
        switch self {
        case .translate:
            "translate"
        case .pronounce:
            "pronounce"
        case .promptMode(let modeID):
            Self.promptModePrefix + modeID
        }
    }
}

/// A stored selection menu entry. The array order is the button order.
public struct SelectionMenuButtonSetting: Codable, Equatable, Sendable {
    public var id: String
    public var isEnabled: Bool

    public init(id: String, isEnabled: Bool) {
        self.id = id
        self.isEnabled = isEnabled
    }
}

public struct SelectionMenuButton: Equatable, Identifiable, Sendable {
    public let action: SelectionMenuAction
    public var isEnabled: Bool

    public var id: String { action.storageID }

    public init(action: SelectionMenuAction, isEnabled: Bool) {
        self.action = action
        self.isEnabled = isEnabled
    }
}

public enum SelectionMenuLayout {
    /// Buttons beyond this count move into the "More" menu.
    public static let maximumInlineButtonCount = 4

    public static func split<Item>(_ items: [Item]) -> (inline: [Item], overflow: [Item]) {
        guard items.count > maximumInlineButtonCount else {
            return (items, [])
        }
        // Keep the last inline slot for the "More" button.
        let inlineCount = maximumInlineButtonCount - 1
        return (Array(items.prefix(inlineCount)), Array(items.dropFirst(inlineCount)))
    }
}

extension SelectionActionsConfig {
    /// Every button the menu can show, in the user's order. Translate and Pronounce
    /// default to on; prompt modes the user has not added yet default to off.
    public func menuButtons(promptModes: [PromptMode]) -> [SelectionMenuButton] {
        let modeIDs = Set(promptModes.map(\.id).filter { $0 != PromptMode.autoID })
        var seen = Set<SelectionMenuAction>()
        var buttons: [SelectionMenuButton] = []

        for setting in menuButtonSettings {
            guard let action = SelectionMenuAction(storageID: setting.id),
                  !seen.contains(action)
            else {
                continue
            }
            if case .promptMode(let modeID) = action, !modeIDs.contains(modeID) {
                continue
            }
            seen.insert(action)
            buttons.append(SelectionMenuButton(action: action, isEnabled: setting.isEnabled))
        }

        for action in [SelectionMenuAction.translate, .pronounce] where !seen.contains(action) {
            seen.insert(action)
            buttons.append(SelectionMenuButton(action: action, isEnabled: true))
        }

        let orderedModes = promptModes
            .filter { modeIDs.contains($0.id) }
            .sorted { $0.sortOrder < $1.sortOrder }
        for mode in orderedModes {
            let action = SelectionMenuAction.promptMode(mode.id)
            guard !seen.contains(action) else { continue }
            seen.insert(action)
            buttons.append(SelectionMenuButton(action: action, isEnabled: false))
        }

        if !buttons.contains(where: \.isEnabled), let index = buttons.firstIndex(where: { $0.action == .translate }) {
            buttons[index].isEnabled = true
        }
        return buttons
    }

    public func enabledMenuButtons(promptModes: [PromptMode]) -> [SelectionMenuButton] {
        menuButtons(promptModes: promptModes).filter(\.isEnabled)
    }

    /// Turns a button on or off. The last enabled button cannot be turned off,
    /// so the menu always has something to show.
    public mutating func setMenuButton(
        _ action: SelectionMenuAction,
        isEnabled: Bool,
        promptModes: [PromptMode]
    ) {
        var buttons = menuButtons(promptModes: promptModes)
        guard let index = buttons.firstIndex(where: { $0.action == action }) else {
            return
        }
        if !isEnabled, buttons.filter(\.isEnabled).count <= 1, buttons[index].isEnabled {
            return
        }
        buttons[index].isEnabled = isEnabled
        menuButtonSettings = buttons.map { SelectionMenuButtonSetting(id: $0.id, isEnabled: $0.isEnabled) }
    }

    public mutating func moveMenuButtons(
        from source: IndexSet,
        to destination: Int,
        promptModes: [PromptMode]
    ) {
        var buttons = menuButtons(promptModes: promptModes)
        let moving = source.sorted().filter { buttons.indices.contains($0) }.map { buttons[$0] }
        guard !moving.isEmpty else { return }
        let insertionIndex = destination - source.filter { $0 < destination }.count
        for index in source.sorted(by: >) where buttons.indices.contains(index) {
            buttons.remove(at: index)
        }
        buttons.insert(contentsOf: moving, at: min(max(insertionIndex, 0), buttons.count))
        menuButtonSettings = buttons.map { SelectionMenuButtonSetting(id: $0.id, isEnabled: $0.isEnabled) }
    }

    public mutating func resetMenuButtons() {
        menuButtonSettings = []
    }
}
