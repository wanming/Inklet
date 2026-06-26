import Foundation

public struct VoicePromptModeSelectionMenuState: Equatable, Sendable {
    public private(set) var selections: [VoicePromptModeSelection]
    public private(set) var selectedIndex: Int

    public init(selections: [VoicePromptModeSelection], selectedIndex: Int = 0) {
        self.selections = selections
        self.selectedIndex = selections.indices.contains(selectedIndex) ? selectedIndex : 0
    }

    public var selectedSelection: VoicePromptModeSelection? {
        guard selections.indices.contains(selectedIndex) else {
            return nil
        }
        return selections[selectedIndex]
    }

    public mutating func moveSelectionUp() {
        guard !selections.isEmpty else {
            return
        }
        selectedIndex = max(selections.startIndex, selectedIndex - 1)
    }

    public mutating func moveSelectionDown() {
        guard !selections.isEmpty else {
            return
        }
        selectedIndex = min(selections.endIndex - 1, selectedIndex + 1)
    }

    @discardableResult
    public mutating func select(index: Int) -> VoicePromptModeSelection? {
        guard selections.indices.contains(index) else {
            return nil
        }
        selectedIndex = index
        return selections[index]
    }
}
